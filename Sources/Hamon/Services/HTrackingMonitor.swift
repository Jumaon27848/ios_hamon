import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Tells `Hamon` when it is worth re-reading the ATT status, so an IDFA granted after the
/// first profile reaches the server right away rather than on the next cold start.
///
/// Two triggers, no host-app code involved:
/// - every `didBecomeActive` — fires when the ATT prompt is dismissed and when the user
///   comes back from flipping the switch in Settings;
/// - a short poll during the first minutes after the first launch, as a safety net for
///   prompts that don't cycle the app's active state. The server holds `first_open` for
///   the same five minutes waiting for the IDFA.
///
/// The monitor only signals; deciding whether anything changed is `Hamon`'s job.
final class HTrackingMonitor {

  static let defaultPollWindow: TimeInterval = 5 * 60
  static let defaultPollInterval: TimeInterval = 3

  /// Assigned by `Hamon` right after construction. Called on the main queue for
  /// activations and on a background queue for polls.
  var onCheck: (() -> Void)?

  private let pollWindow: TimeInterval
  private let pollInterval: TimeInterval
  private let queue = DispatchQueue(label: "com.hamon.tracking", qos: .utility)

  private let lock = NSLock()
  private var observing = false
  private var timer: DispatchSourceTimer?

  /// `pollWindow` and `pollInterval` are shortened by tests so they don't have to wait
  /// five minutes.
  init(
    pollWindow: TimeInterval = HTrackingMonitor.defaultPollWindow,
    pollInterval: TimeInterval = HTrackingMonitor.defaultPollInterval
  ) {
    self.pollWindow = pollWindow
    self.pollInterval = pollInterval
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    timer?.cancel()
  }

  /// Idempotent. Polls only while still inside the window that starts at `firstLaunch`.
  func start(firstLaunch: Date) {
    lock.lock()
    let alreadyObserving = observing
    observing = true
    lock.unlock()
    guard !alreadyObserving else { return }

#if canImport(UIKit)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
#endif

    startPolling(until: firstLaunch.addingTimeInterval(pollWindow))
  }

  /// Ends the poll early — called once the IDFA has been reported. Activations are still
  /// observed.
  func stopPolling() {
    lock.lock()
    let current = timer
    timer = nil
    lock.unlock()
    current?.cancel()
  }

  var isPolling: Bool {
    lock.lock()
    defer { lock.unlock() }
    return timer != nil
  }

  private func startPolling(until deadline: Date) {
    guard Date() < deadline else { return }

    let source = DispatchSource.makeTimerSource(queue: queue)
    source.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
    source.setEventHandler { [weak self] in
      guard let self = self else { return }
      guard Date() < deadline else {
        self.stopPolling()
        return
      }
      self.onCheck?()
    }

    lock.lock()
    timer = source
    lock.unlock()
    source.resume()
  }

  @objc private func handleDidBecomeActive() {
    onCheck?()
  }
}
