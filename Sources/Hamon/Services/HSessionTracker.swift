import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects `session_length_first` and `taps_count_first_30s`.
///
/// Both are first-occurrence-only: once measured they are frozen in `HStorage` and never
/// recomputed. `onMetricLocked` fires when either one settles, so the freshly available
/// value ships without waiting for the next setter call.
final class HSessionTracker {

  /// Android anchors the tap window at the first Activity creation; the iOS equivalent is
  /// the first foreground activation.
  static let defaultTapWindow: TimeInterval = 30

  private let storage: HStorage
  private let tapWindow: TimeInterval

  /// Assigned by `Hamon` right after construction, following the same shape as
  /// `HEventQueue.onFlush`.
  var onMetricLocked: (() -> Void)?

  private let lock = NSLock()
  private var sessionStart: Date?
  private var tapCount = 0
  private var tapTrackingEnabled = false
  private var tapWindowAnchored = false
  private var tapsLocked = false
  private var observing = false

  /// The swizzled `UIWindow.sendEvent(_:)` funnels taps here. Weak so a released tracker
  /// silently stops counting instead of keeping the singleton alive.
  fileprivate static weak var tapSink: HSessionTracker?

  /// - Parameter tapWindow: shortened by tests so they don't have to wait half a minute.
  init(storage: HStorage, tapWindow: TimeInterval = HSessionTracker.defaultTapWindow) {
    self.storage = storage
    self.tapWindow = tapWindow
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Collected values

  /// Length of the first foreground session in milliseconds. `nil` until it has been
  /// measured — that is, until the app has been backgrounded once.
  var sessionLengthFirst: Int? {
    storage.optionalInteger(for: .sessionLengthFirst)
  }

  /// Taps in the first 30 seconds. `nil` unless ``enableTapTracking()`` was called and
  /// the window has since elapsed. `0` is a real value and is reported as `0`.
  var tapsCountFirst30s: Int? {
    storage.optionalInteger(for: .tapsCountFirst30s)
  }

  // MARK: - Lifecycle

  func start() {
    guard sessionLengthFirst == nil || tapsCountFirst30s == nil else {
      // Both metrics already settled in an earlier launch — nothing left to observe.
      return
    }

    lock.lock()
    let alreadyObserving = observing
    observing = true
    lock.unlock()
    guard !alreadyObserving else { return }

#if canImport(UIKit)
    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(handleDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(handleDidEnterBackground),
      name: UIApplication.willTerminateNotification,
      object: nil
    )
#endif
  }

  /// Opts into counting taps, which requires swizzling `UIWindow.sendEvent(_:)`.
  ///
  /// Off by default: swizzling is process-wide and can collide with other SDKs that hook
  /// the same method, so it is the host app's call to make. Public API only — App Store safe.
  func enableTapTracking() {
    guard tapsCountFirst30s == nil else { return }

    lock.lock()
    tapTrackingEnabled = true
    HSessionTracker.tapSink = self
    lock.unlock()

#if canImport(UIKit)
    _ = HSessionTracker.swizzleSendEvent
    // The first activation may already have happened by the time the host opts in.
    if Thread.isMainThread, UIApplication.shared.applicationState == .active {
      anchorTapWindow()
    }
#endif
  }

  // MARK: - Notifications

  @objc private func handleDidBecomeActive() {
    lock.lock()
    if sessionStart == nil, storage.optionalInteger(for: .sessionLengthFirst) == nil {
      sessionStart = Date()
    }
    lock.unlock()

    anchorTapWindow()
  }

  @objc private func handleDidEnterBackground() {
    lock.lock()
    let start = sessionStart
    sessionStart = nil
    lock.unlock()

    guard let start = start, sessionLengthFirst == nil else { return }

    let milliseconds = Int((Date().timeIntervalSince(start) * 1000).rounded())
    storage.set(max(0, milliseconds), for: .sessionLengthFirst)
    onMetricLocked?()
  }

  // MARK: - Taps

  private func anchorTapWindow() {
    lock.lock()
    let shouldAnchor = tapTrackingEnabled && !tapWindowAnchored
    if shouldAnchor { tapWindowAnchored = true }
    lock.unlock()

    guard shouldAnchor else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + tapWindow) { [weak self] in
      self?.lockTaps()
    }
  }

  private func lockTaps() {
    guard tapsCountFirst30s == nil else { return }

    lock.lock()
    let count = tapCount
    tapsLocked = true
    lock.unlock()

    storage.set(count, for: .tapsCountFirst30s)
    onMetricLocked?()
  }

  /// Called from the swizzled `UIWindow.sendEvent(_:)` — one call per began-phase event.
  func recordTap() {
    lock.lock()
    if tapTrackingEnabled, tapWindowAnchored, !tapsLocked { tapCount += 1 }
    lock.unlock()
  }

#if canImport(UIKit)
  /// `static let` gives us exchange-exactly-once semantics for free.
  private static let swizzleSendEvent: Void = {
    guard
      let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
      let replacement = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.hamon_sendEvent(_:)))
    else {
#if DEBUG
      debugPrint("[Hamon] ⚠️ Tap tracking unavailable: could not swizzle UIWindow.sendEvent")
#endif
      return
    }
    method_exchangeImplementations(original, replacement)
  }()
#endif
}

#if canImport(UIKit)
private extension UIWindow {
  /// After the exchange this selector holds the original implementation, so the call at
  /// the end of the body is the real `sendEvent(_:)` — not recursion.
  @objc func hamon_sendEvent(_ event: UIEvent) {
    // One increment per event carrying a began-phase touch. This mirrors Android's
    // ACTION_DOWN: a two-finger gesture counts once, not twice.
    if event.type == .touches,
       event.allTouches?.contains(where: { $0.phase == .began }) == true {
      HSessionTracker.tapSink?.recordTap()
    }

    hamon_sendEvent(event)
  }
}
#endif
