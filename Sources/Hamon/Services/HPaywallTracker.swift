import Foundation

/// Tracks the paywall funnel: `time_to_paywall`, `actions_before_paywall`,
/// `inters_shown_before_paywall`, `aoa_shown_before_paywall`, `paywall_conversion_time`
/// and `click_to_pay_time`.
///
/// Nothing here is autonomous — the SDK does not introspect screens or purchases. The host
/// app calls the `notify…` methods at the right moments and this class does the bookkeeping.
/// Every field is first-occurrence-only and persisted, so the funnel survives process death.
///
/// **Units differ per field and the wire names do not reveal it:**
/// `time_to_paywall` is milliseconds, `paywall_conversion_time` is **microseconds**, and
/// `click_to_pay_time` is **whole seconds**. This matches the Android schema exactly.
final class HPaywallTracker {

  private let storage: HStorage
  private let lock = NSLock()

  init(storage: HStorage) {
    self.storage = storage
  }

  // MARK: - Collected values

  /// Milliseconds from first app open to the first paywall.
  var timeToPaywall: Int? { storage.optionalInteger(for: .timeToPaywall) }

  var actionsBeforePaywall: Int? { storage.optionalInteger(for: .actionsBeforePaywall) }

  var intersShownBeforePaywall: Int? {
    storage.optionalInteger(for: .intersShownBeforePaywall)
  }

  var aoaShownBeforePaywall: Int? { storage.optionalInteger(for: .aoaShownBeforePaywall) }

  /// **Microseconds** from the first paywall open to the first buy tap.
  var paywallConversionTime: Int? { storage.optionalInteger(for: .paywallConversionTime) }

  /// **Whole seconds**, floored, from the first buy tap to the purchase completing.
  var clickToPayTime: Int? { storage.optionalInteger(for: .clickToPayTime) }

  // MARK: - Funnel signals

  /// Locks `time_to_paywall` and freezes the three running counters. Later calls are no-ops.
  /// - Returns: `true` when this call actually locked something.
  @discardableResult
  func notifyPaywallOpened() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard storage.optionalDouble(for: .firstPaywallOpenedAt) == nil else { return false }

    let now = Date().timeIntervalSince1970
    let firstOpenMillis = storage.integer(for: .firstOpenTimestamp)
    if firstOpenMillis > 0 {
      let elapsed = Int(now * 1000) - firstOpenMillis
      storage.set(max(0, elapsed), for: .timeToPaywall)
    }

    storage.set(storage.integer(for: .actionsCount), for: .actionsBeforePaywall)
    storage.set(storage.integer(for: .intersCount), for: .intersShownBeforePaywall)
    storage.set(storage.integer(for: .aoaCount), for: .aoaShownBeforePaywall)
    storage.set(now, for: .firstPaywallOpenedAt)
    return true
  }

  /// Locks `paywall_conversion_time`. Silently ignored until a paywall has been reported.
  @discardableResult
  func notifyPurchaseStarted() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard let paywallOpenedAt = storage.optionalDouble(for: .firstPaywallOpenedAt) else {
#if DEBUG
      debugPrint("[Hamon] ⚠️ notifyPurchaseStarted ignored: no paywall reported yet")
#endif
      return false
    }
    guard storage.optionalDouble(for: .firstPurchaseStartedAt) == nil else { return false }

    let now = Date().timeIntervalSince1970
    let microseconds = Int(((now - paywallOpenedAt) * 1_000_000).rounded())
    storage.set(max(0, microseconds), for: .paywallConversionTime)
    storage.set(now, for: .firstPurchaseStartedAt)
    return true
  }

  /// Locks `click_to_pay_time`. Silently ignored until a purchase has been started.
  @discardableResult
  func notifyPurchaseCompleted() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard let startedAt = storage.optionalDouble(for: .firstPurchaseStartedAt) else {
#if DEBUG
      debugPrint("[Hamon] ⚠️ notifyPurchaseCompleted ignored: no purchase started yet")
#endif
      return false
    }
    guard storage.optionalInteger(for: .clickToPayTime) == nil else { return false }

    // Floored to whole seconds, matching Android — a 1.9 s billing flow reports 1.
    let seconds = Int(Date().timeIntervalSince1970 - startedAt)
    storage.set(max(0, seconds), for: .clickToPayTime)
    return true
  }

  // MARK: - Counters

  func notifyUserAction() { increment(.actionsCount) }

  func notifyInterstitialShown() { increment(.intersCount) }

  func notifyAoaShown() { increment(.aoaCount) }

  /// Counters stop once the paywall has frozen them — after that they cannot influence
  /// any reported field, so there is nothing to gain from writing to disk.
  private func increment(_ key: HStorage.Key) {
    lock.lock()
    defer { lock.unlock() }

    guard storage.optionalDouble(for: .firstPaywallOpenedAt) == nil else { return }
    storage.set(storage.integer(for: key) + 1, for: key)
  }
}
