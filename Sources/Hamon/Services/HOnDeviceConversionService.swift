import Foundation
import ObjectiveC

/// Obtains `odm_info` — the string Google's on-device conversion library hands out for
/// Integrated Conversion Measurement. The backend forwards it in the `first_open` request
/// to the App Conversion API, which lets Google attribute installs that have no IDFA.
///
/// The library (`GoogleAdsOnDeviceConversion`) is deliberately not a dependency of this
/// package: host apps already get it through Firebase Analytics (CocoaPods), and a second
/// copy pulled in by SwiftPM would collide with it. It is reached through the Objective-C
/// runtime instead — the `ODCConversionManager` API is identical from 2.1.0 to 3.7.0. When
/// the library is absent the service simply gives up and the field is never sent.
///
/// Runs once per install, and only for installs whose first launch happened on an SDK
/// that knows about this — Google wants the string tied to the real first launch.
final class HOnDeviceConversionService {

  /// What a single fetch produced.
  enum FetchResult {
    case info(String)
    /// The library answered with nothing: outside the approved regions (EEA, UK and
    /// Switzerland get nothing by design) or the info has expired. Not worth retrying.
    case unavailable
    /// `GoogleAdsOnDeviceConversion` is not linked into the host app.
    case libraryMissing
    /// Usually a network failure — retried, see ``maxAttempts``.
    case failed(Error)
  }

  typealias Fetcher = (_ firstLaunch: Date, _ completion: @escaping (FetchResult) -> Void) -> Void

  private enum State: String {
    case pending
    case done
  }

  /// Total attempts per install, across launches.
  static let maxAttempts = 3

  private let storage: HStorage
  private let fetcher: Fetcher
  private let retryDelay: TimeInterval

  /// Fires once, on whatever queue the library calls back on, when `odm_info` is stored.
  var onInfoAvailable: (() -> Void)?

  private let lock = NSLock()
  private var inFlight = false

  /// - Parameter retryDelay: shortened by tests; the n-th retry waits `retryDelay * n`.
  init(
    storage: HStorage,
    retryDelay: TimeInterval = 15,
    fetcher: @escaping Fetcher = HOnDeviceConversionService.fetchFromGoogleLibrary
  ) {
    self.storage = storage
    self.retryDelay = retryDelay
    self.fetcher = fetcher
  }

  /// The stored string, or `nil` if there is none (yet).
  var odmInfo: String? {
    storage.string(for: .odmInfo)
  }

  /// Marks this install as eligible. Must be called only on the very first launch — that
  /// is, before the first-open timestamp is recorded.
  func markNewInstall() {
    storage.set(State.pending.rawValue, for: .odmState)
  }

  /// Fetches unless already done, not eligible, or a fetch is in flight.
  func fetchIfNeeded(firstLaunch: Date) {
    guard storage.string(for: .odmState) == State.pending.rawValue else { return }

    lock.lock()
    let alreadyFetching = inFlight
    inFlight = true
    lock.unlock()
    guard !alreadyFetching else { return }

    fetcher(firstLaunch) { [weak self] result in
      self?.handle(result, firstLaunch: firstLaunch)
    }
  }

  private func handle(_ result: FetchResult, firstLaunch: Date) {
    var retryAfter: TimeInterval?

    switch result {
    case .info(let info):
      storage.set(info, for: .odmInfo)
      storage.set(State.done.rawValue, for: .odmState)
#if DEBUG
      debugPrint("[Hamon] ✅ odm_info received")
#endif
    case .unavailable:
      storage.set(State.done.rawValue, for: .odmState)
#if DEBUG
      debugPrint("[Hamon] ℹ️ odm_info is not available for this install")
#endif
    case .libraryMissing:
      storage.set(State.done.rawValue, for: .odmState)
#if DEBUG
      debugPrint("[Hamon] ⚠️ GoogleAdsOnDeviceConversion not found — odm_info will not be sent. Add Firebase Analytics 11.14.0+")
#endif
    case .failed(let error):
      let attempts = storage.integer(for: .odmAttempts) + 1
      storage.set(attempts, for: .odmAttempts)
      if attempts >= HOnDeviceConversionService.maxAttempts {
        storage.set(State.done.rawValue, for: .odmState)
      } else {
        retryAfter = retryDelay * TimeInterval(attempts)
      }
#if DEBUG
      debugPrint("[Hamon] ❌ odm_info fetch failed (attempt \(attempts)): \(error.localizedDescription)")
#endif
    }

    lock.lock()
    inFlight = false
    lock.unlock()

    if case .info = result {
      onInfoAvailable?()
    }

    if let delay = retryAfter {
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
        self?.fetchIfNeeded(firstLaunch: firstLaunch)
      }
    }
  }

  // MARK: - GoogleAdsOnDeviceConversion via the Objective-C runtime

  /// `ODCInteractionTypeInstallation` — the first case of an `NS_ENUM(NSInteger)`, the same
  /// in every version we ship (2.1.0 … 3.7.0).
  private static let installationInteraction = 0

  private static let setFirstLaunchTimeSelector = NSSelectorFromString("setFirstLaunchTime:")
  private static let fetchSelector = NSSelectorFromString(
    "fetchAggregateConversionInfoForInteraction:completion:"
  )

  private typealias SharedInstanceIMP = @convention(c) (AnyClass, Selector) -> Unmanaged<NSObject>?
  private typealias SetFirstLaunchTimeIMP = @convention(c) (NSObject, Selector, NSDate) -> Void
  private typealias FetchIMP = @convention(c) (
    NSObject, Selector, Int, @escaping @convention(block) (NSString?, NSError?) -> Void
  ) -> Void

  /// Equivalent of:
  /// ```swift
  /// ConversionManager.sharedInstance.setFirstLaunchTime(firstLaunch)
  /// ConversionManager.sharedInstance.fetchAggregateConversionInfo(for: .installation) { … }
  /// ```
  static func fetchFromGoogleLibrary(
    firstLaunch: Date,
    completion: @escaping (FetchResult) -> Void
  ) {
    guard let manager = googleConversionManager(),
          manager.responds(to: setFirstLaunchTimeSelector),
          manager.responds(to: fetchSelector) else {
      completion(.libraryMissing)
      return
    }

    let setFirstLaunchTime = unsafeBitCast(
      manager.method(for: setFirstLaunchTimeSelector),
      to: SetFirstLaunchTimeIMP.self
    )
    setFirstLaunchTime(manager, setFirstLaunchTimeSelector, firstLaunch as NSDate)

    let fetch = unsafeBitCast(manager.method(for: fetchSelector), to: FetchIMP.self)
    fetch(manager, fetchSelector, installationInteraction) { info, error in
      if let error = error {
        completion(.failed(error))
      } else if let info = info as String?, !info.isEmpty {
        completion(.info(info))
      } else {
        // Both nil means "expired / not available", per the library's header.
        completion(.unavailable)
      }
    }
  }

  private static func googleConversionManager() -> NSObject? {
    guard let managerClass = NSClassFromString("ODCConversionManager") else { return nil }
    let selector = NSSelectorFromString("sharedInstance")
    guard let method = class_getClassMethod(managerClass, selector) else { return nil }
    let sharedInstance = unsafeBitCast(method_getImplementation(method), to: SharedInstanceIMP.self)
    return sharedInstance(managerClass, selector)?.takeUnretainedValue()
  }
}
