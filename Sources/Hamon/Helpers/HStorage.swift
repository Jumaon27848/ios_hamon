import Foundation

/// Persistent storage for the identifiers that reach the SDK after launch —
/// FCM token, user id, attribution ids.
///
/// Backed by `UserDefaults` and deliberately not the Keychain: every value here
/// belongs to the current install and must die with the app. Keychain entries
/// survive deletion, so a reinstall would resurrect a stale FCM token and a
/// stale App Instance ID, both of which Firebase has already regenerated.
final class HStorage {

  enum Key: String, CaseIterable {
    case userId = "Hamon_userId"
    case fcmToken = "Hamon_fcmToken"
    case affiseId = "Hamon_affiseId"
    case promoCode = "Hamon_promoCode"
    case webCustomerId = "Hamon_webCustomerId"
    case gdprConsentStatus = "Hamon_gdprConsentStatus"
    case appsflyerId = "Hamon_appsflyerId"
    case sessionLengthFirst = "Hamon_sessionLengthFirst"
    case tapsCountFirst30s = "Hamon_tapsCountFirst30s"

    // Paywall funnel. The `*Count` keys are running tallies that never ship; they are
    // frozen into the matching `*BeforePaywall` keys when the paywall first opens.
    case actionsCount = "Hamon_paywall_actionsCount"
    case intersCount = "Hamon_paywall_intersCount"
    case aoaCount = "Hamon_paywall_aoaCount"
    case timeToPaywall = "Hamon_paywall_timeToPaywall"
    case actionsBeforePaywall = "Hamon_paywall_actionsBeforePaywall"
    case intersShownBeforePaywall = "Hamon_paywall_intersShownBeforePaywall"
    case aoaShownBeforePaywall = "Hamon_paywall_aoaShownBeforePaywall"
    /// Doubles as the "paywall has opened" sentinel and the conversion baseline.
    case firstPaywallOpenedAt = "Hamon_paywall_firstPaywallOpenedAt"
    /// Doubles as the "purchase started" sentinel and the click-to-pay baseline.
    case firstPurchaseStartedAt = "Hamon_paywall_firstPurchaseStartedAt"
    case paywallConversionTime = "Hamon_paywall_conversionTime"
    case clickToPayTime = "Hamon_paywall_clickToPayTime"
    /// Pre-existing key — kept verbatim so installs from earlier versions
    /// don't lose their first-open timestamp.
    case firstOpenTimestamp = "Hamon_firstOpenTimestamp"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  // MARK: - Strings

  func string(for key: Key) -> String? {
    guard let value = defaults.string(forKey: key.rawValue), !value.isEmpty else {
      return nil
    }
    return value
  }

  func set(_ value: String?, for key: Key) {
    if let value = value, !value.isEmpty {
      defaults.set(value, forKey: key.rawValue)
    } else {
      defaults.removeObject(forKey: key.rawValue)
    }
  }

  // MARK: - Integers

  /// Returns 0 when the key was never written.
  func integer(for key: Key) -> Int {
    defaults.integer(forKey: key.rawValue)
  }

  /// `nil` when the key was never written — the distinction matters for metrics where a
  /// genuine `0` (no taps, no actions before the paywall) has to survive as `0` rather
  /// than read back as "not measured".
  func optionalInteger(for key: Key) -> Int? {
    guard defaults.object(forKey: key.rawValue) != nil else { return nil }
    return defaults.integer(forKey: key.rawValue)
  }

  func set(_ value: Int, for key: Key) {
    defaults.set(value, forKey: key.rawValue)
  }

  // MARK: - Doubles

  /// `nil` when the key was never written. Used for funnel timestamps, which need
  /// sub-millisecond resolution to survive the conversion to microseconds.
  func optionalDouble(for key: Key) -> Double? {
    guard defaults.object(forKey: key.rawValue) != nil else { return nil }
    return defaults.double(forKey: key.rawValue)
  }

  func set(_ value: Double, for key: Key) {
    defaults.set(value, forKey: key.rawValue)
  }

  // MARK: - Maintenance

  /// Removes every key the SDK owns. Used by tests.
  func reset() {
    Key.allCases.forEach { defaults.removeObject(forKey: $0.rawValue) }
  }
}
