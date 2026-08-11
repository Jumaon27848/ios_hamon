import Foundation

public final class Hamon {

  // MARK: - Singleton
  public static let shared = Hamon()

  // MARK: - Properties

  /// Everything below is guarded by `lock` — setters run on the caller's thread
  /// while `updateUserDataSync` and the public getters read from elsewhere.
  private let lock = NSLock()

  private var isInitialized = false
  private var baseURL: String?
  private var _userId: String?
  private var fcmToken: String?
  private var affiseID: String?
  private var promoCode: String?
  private var webCustomerID: String?
  private var gdprConsentStatus: String?
  private var appsflyerId: String?
  private var networkService: HNetworkService?
  private var updateGeneration = 0

  private let deviceInfoService = HDeviceInfoService()
  private let encryptionService = HEncryptionService()
  private let eventQueue = HEventQueue()
  private let storage = HStorage()
  private let connectivityService = HConnectivityService()
  private let sessionTracker: HSessionTracker
  private let paywallTracker: HPaywallTracker

  /// Serial, so two PATCHes can never overlap or land out of order.
  private let updateQueue = DispatchQueue(label: "com.hamon.userdata", qos: .utility)

  /// Setters tend to arrive in bursts at launch (`setUserId`, `setFCM`, `setAffiseId`
  /// within the same run loop). Collapsing them into one PATCH avoids a storm of
  /// near-identical requests.
  private static let updateCoalescingDelay: DispatchTimeInterval = .milliseconds(300)

  private init() {
    sessionTracker = HSessionTracker(storage: storage)
    paywallTracker = HPaywallTracker(storage: storage)
    recordFirstOpenIfNeeded()
    restoreState()
    setupEventQueueCallback()
    sessionTracker.onMetricLocked = { [weak self] in
      self?.scheduleUserDataUpdate()
    }
  }

  // MARK: - Configuration

  /// Configure SDK with server IP
  /// - Parameters:
  ///   - host: Server IP address (e.g., "192.168.1.100" or "your.domain.com" for https)
  ///   - useHTTPS: Use HTTPS protocol (default: false)
  ///   - userId: Optional user identifier (Only if using custom user id instead of Firebase App Instance ID)
  public func configure(host: String, useHTTPS: Bool = false, userId: String? = nil) {
    HConfigHelper.checkATSConfiguration(for: host, useHTTPS: useHTTPS)

    let service = HNetworkService(
      serverIP: host,
      useHTTPS: useHTTPS,
      encryptionService: encryptionService
    )

    synchronized {
      self.baseURL = host
      self.networkService = service
      self.isInitialized = true
    }

    sessionTracker.start()

    if let userId = userId {
      setUserId(userId)
    }

    // Report on every cold start, whether the id was just supplied or restored from
    // a previous launch — so the first PATCH carries the cached identifiers instead
    // of overwriting the server with nulls while we wait for the host app to hand
    // them over again. `setUserId` above may well have been a no-op (same id as last
    // launch), so this cannot be left to the setters. The debounce collapses the
    // duplicate into one request.
    guard self.userId != nil else {
#if DEBUG
      debugPrint("[Hamon] ⚠️ Waiting for userId (Firebase App Instance ID preffered)")
#endif
      return
    }
    scheduleUserDataUpdate()
  }

  // MARK: - Set userId externally

  /// Set user ID (Firebase App Instance ID recommended)
  public func setUserId(_ userId: String) {
    guard store(userId, in: \._userId, as: .userId) else { return }
#if DEBUG
    debugPrint("[Hamon] ✅ userId set: \(userId)")
#endif
    scheduleUserDataUpdate()
  }

  // MARK: - Set affise id

  /// Set Affise ID (Affise Integration with click id)
  public func setAffiseId(_ id: String) {
    guard store(id, in: \.affiseID, as: .affiseId) else { return }
#if DEBUG
    debugPrint("[Hamon] ✅ Affise ID set: \(id)")
#endif
    scheduleUserDataUpdate()
  }

  // MARK: - Set web customer id

  /// Set Web Customer ID (web-to-app user linking)
  public func setWebCustomerId(_ id: String) {
    guard store(id, in: \.webCustomerID, as: .webCustomerId) else { return }
#if DEBUG
    debugPrint("[Hamon] ✅ Web Customer ID set: \(id)")
#endif
    scheduleUserDataUpdate()
  }

  // MARK: - Set FCM Token

  /// Set Firebase Cloud Messaging token.
  ///
  /// Call this from `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)`
  /// rather than reading `Messaging.messaging().fcmToken` once — the delegate also
  /// fires when the token arrives late or rotates. The value is cached across
  /// launches, so it only has to be supplied once per token.
  public func setFCM(token: String) {
    guard store(token, in: \.fcmToken, as: .fcmToken) else { return }
#if DEBUG
    debugPrint("[Hamon] ✅ FCM token set")
#endif
    scheduleUserDataUpdate()
  }

  // MARK: - Set Promo Code
  public func setPromoCode(_ code: String) {
    guard store(code, in: \.promoCode, as: .promoCode) else { return }
    scheduleUserDataUpdate()
  }

  // MARK: - Set GDPR consent

  /// Record the user's GDPR consent decision, reported as `gdpr_consent_status`.
  ///
  /// Accepts only ``GdprConsent`` values. Until it is set, the SDK reports
  /// ``GdprConsent/unknown`` — the field is never null.
  public func setGdprConsent(_ status: GdprConsent) {
    guard store(status.rawValue, in: \.gdprConsentStatus, as: .gdprConsentStatus) else {
      return
    }
#if DEBUG
    debugPrint("[Hamon] ✅ GDPR consent set: \(status.rawValue)")
#endif
    scheduleUserDataUpdate()
  }

  /// String overload for hosts bridging from Kotlin/JS where the enum isn't available.
  /// Invalid values are ignored — the previous decision survives, matching Android.
  public func setGdprConsent(_ status: String) {
    guard let consent = GdprConsent(rawValue: status) else {
#if DEBUG
      debugPrint("[Hamon] ⚠️ setGdprConsent ignored: invalid status \"\(status)\"")
#endif
      return
    }
    setGdprConsent(consent)
  }

  /// The three values the backend accepts for `gdpr_consent_status`.
  public enum GdprConsent: String {
    case accepted
    case rejected
    case unknown
  }

  // MARK: - Set AppsFlyer ID

  /// Set the AppsFlyer device ID, reported as `appsflyer_id`.
  ///
  /// Pass `AppsFlyerLib.shared().getAppsFlyerUID()` once AppsFlyer has started. The value
  /// is sticky: once recorded it is never cleared, so a later AppsFlyer failure cannot
  /// blank out an id the backend has already seen.
  public func setAppsFlyerId(_ id: String) {
    guard !id.isEmpty else { return }
    guard store(id, in: \.appsflyerId, as: .appsflyerId) else { return }
#if DEBUG
    debugPrint("[Hamon] ✅ AppsFlyer ID set: \(id)")
#endif
    scheduleUserDataUpdate()
  }

  // MARK: - Paywall Funnel

  /// Signals that the paywall was shown.
  ///
  /// The first call ever locks in `time_to_paywall` (milliseconds since first app open)
  /// and freezes `actions_before_paywall`, `inters_shown_before_paywall` and
  /// `aoa_shown_before_paywall` from the running counters. Later calls are no-ops.
  /// Locked values survive process death.
  public func notifyPaywallOpened() {
    guard paywallTracker.notifyPaywallOpened() else { return }
    scheduleUserDataUpdate()
  }

  /// Signals that the user pressed the buy button.
  ///
  /// The first call after ``notifyPaywallOpened()`` locks in `paywall_conversion_time`,
  /// **in microseconds**. Ignored if no paywall has been reported yet — there is no
  /// retro-fill, so the ordering matters.
  public func notifyPurchaseStarted() {
    guard paywallTracker.notifyPurchaseStarted() else { return }
    scheduleUserDataUpdate()
  }

  /// Signals that the billing flow finished and the purchase was granted.
  ///
  /// The first call after ``notifyPurchaseStarted()`` locks in `click_to_pay_time`,
  /// **in whole seconds** — a sub-second flow reports `0`. Ignored if no purchase was
  /// started.
  public func notifyPurchaseCompleted() {
    guard paywallTracker.notifyPurchaseCompleted() else { return }
    scheduleUserDataUpdate()
  }

  /// Increments the count of user interactions before the paywall.
  ///
  /// Frozen into `actions_before_paywall` by the first ``notifyPaywallOpened()``. What
  /// counts as an action is entirely up to the host app — typically a tap handler in a
  /// base view controller. Distinct from `taps_count_first_30s`, which is automatic.
  public func notifyUserAction() {
    paywallTracker.notifyUserAction()
  }

  /// Increments the count of interstitial ads shown, frozen into
  /// `inters_shown_before_paywall` by the first ``notifyPaywallOpened()``.
  public func notifyInterstitialShown() {
    paywallTracker.notifyInterstitialShown()
  }

  /// Increments the count of App Open Ads shown, frozen into `aoa_shown_before_paywall`
  /// by the first ``notifyPaywallOpened()``.
  public func notifyAoaShown() {
    paywallTracker.notifyAoaShown()
  }

  // MARK: - Tap tracking

  /// Opt into collecting `taps_count_first_30s`.
  ///
  /// Counting taps requires swizzling `UIWindow.sendEvent(_:)`, which is process-wide and
  /// can collide with other SDKs that hook the same method — so it is off unless the host
  /// app asks for it. Uses public API only. Call once, early, alongside `configure`.
  public func enableTapTracking() {
    sessionTracker.enableTapTracking()
  }

  // MARK: - Identity

  /// The identifier this instance reports to Hamon — the Firebase App Instance ID
  /// unless a custom id was supplied. Restored automatically across launches.
  public var userId: String? {
    synchronized { _userId }
  }

  /// ``userId`` reshaped into the RFC 4122 layout StoreKit requires for
  /// `appAccountToken`, or `nil` when no id is set or it isn't 32 hex characters.
  ///
  /// ```swift
  /// var options: Set<Product.PurchaseOption> = []
  /// if let token = Hamon.shared.appAccountToken {
  ///   options.insert(.appAccountToken(token))
  /// }
  /// let result = try await product.purchase(options: options)
  /// ```
  ///
  /// Apple writes the token into the transaction permanently and echoes it back in
  /// App Store Server Notifications, which is what lets the backend match a purchase
  /// to this instance. Pass it on every purchase — subscription, resubscription and
  /// one-off alike; renewals inherit it automatically.
  public var appAccountToken: UUID? {
    guard let userId = userId else { return nil }
    return Hamon.appAccountToken(from: userId)
  }

  /// Converts a Firebase App Instance ID (32 hex characters, no dashes) into the
  /// RFC 4122 layout Apple requires for `appAccountToken`.
  ///
  /// `"b9660c2a16297c54d42d5a3986c6e6c8"` → `"b9660c2a-1629-7c54-d42d-5a3986c6e6c8"`
  ///
  /// Only dashes are inserted — the characters themselves are untouched, so the
  /// backend recovers the original App Instance ID by stripping them back out. The
  /// result is therefore usually not a valid UUIDv4 (the version nibble is whatever
  /// Firebase produced), which is fine: StoreKit only requires the 8-4-4-4-12 shape.
  ///
  /// - Returns: `nil` unless the input is exactly 32 hexadecimal characters.
  public static func appAccountToken(from appInstanceID: String) -> UUID? {
    let normalized = appInstanceID
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()

    // Deliberately not `Character.isHexDigit`, which also accepts fullwidth and
    // other Unicode hex forms that UUID(uuidString:) would reject.
    guard normalized.count == 32,
          normalized.allSatisfy({ hexDigits.contains($0) }) else {
      return nil
    }

    let characters = Array(normalized)
    let hyphenated = String(characters[0..<8]) + "-"
      + String(characters[8..<12]) + "-"
      + String(characters[12..<16]) + "-"
      + String(characters[16..<20]) + "-"
      + String(characters[20..<32])

    return UUID(uuidString: hyphenated)
  }

  private static let hexDigits = Set("0123456789abcdef")

  // MARK: - Event Tracking

  /// Log analytics event
  /// - Parameters:
  ///   - name: Event name
  ///   - parameters: Event parameters (optional)
  public func logEvent(_ name: String, parameters: [String: Any] = [:]) {
    guard synchronized({ isInitialized }) else {
#if DEBUG
      debugPrint("[Hamon] ❌ SDK not initialized")
#endif
      return
    }

    let event = HAnalyticsEvent(name: name, parameters: parameters)
    eventQueue.add(event: event)
#if DEBUG
    debugPrint("[Hamon] ✅ Event logged: \(name)")
#endif
  }

  /// Force send all buffered events
  public func flush() {
    eventQueue.flush()
  }

  /// Clear event queue without sending
  public func clearQueue() {
    eventQueue.clear()
  }

  /// Generate Info.plist XML for ATS configuration
  public func generateInfoPlistConfiguration(host: String) -> String {
    HConfigHelper.generateInfoPlistXML(for: host)
  }

  /// Test connection to server
  public func testConnection(host: String, completion: @escaping (Bool, String) -> Void) {
    HConfigHelper.testConnection(to: host) { status, message in
      completion(status, message)
    }
  }

  // MARK: - State

  private func synchronized<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  /// Stamped as early as possible — the SDK is constructed on the host's first touch of
  /// `Hamon.shared`. Recording it here rather than on the first successful PATCH means
  /// `time_to_paywall` has a baseline even when no `userId` is ever supplied, and
  /// `app_first_open_timestamp` is closer to the truth.
  private func recordFirstOpenIfNeeded() {
    guard storage.integer(for: .firstOpenTimestamp) == 0 else { return }
    storage.set(Int(Date().timeIntervalSince1970 * 1000), for: .firstOpenTimestamp)
  }

  private func restoreState() {
    _userId = storage.string(for: .userId)
    fcmToken = storage.string(for: .fcmToken)
    affiseID = storage.string(for: .affiseId)
    promoCode = storage.string(for: .promoCode)
    webCustomerID = storage.string(for: .webCustomerId)
    gdprConsentStatus = storage.string(for: .gdprConsentStatus)
    appsflyerId = storage.string(for: .appsflyerId)
  }

  /// Assigns `value` and persists it. Returns `false` when nothing changed, so
  /// callers can skip a pointless PATCH.
  private func store(
    _ value: String,
    in keyPath: ReferenceWritableKeyPath<Hamon, String?>,
    as key: HStorage.Key
  ) -> Bool {
    let changed = synchronized { () -> Bool in
      guard self[keyPath: keyPath] != value else { return false }
      self[keyPath: keyPath] = value
      return true
    }
    guard changed else { return false }
    storage.set(value, for: key)
    return true
  }

  // MARK: - Private Methods

  /// Coalesces bursts of setter calls into a single PATCH — only the last
  /// scheduled update survives the debounce window.
  private func scheduleUserDataUpdate() {
    let generation = synchronized { () -> Int in
      updateGeneration &+= 1
      return updateGeneration
    }

    updateQueue.asyncAfter(deadline: .now() + Hamon.updateCoalescingDelay) { [weak self] in
      guard let self = self else { return }
      guard self.synchronized({ generation == self.updateGeneration }) else { return }
      self.updateUserDataSync()
    }
  }

  private func setupEventQueueCallback() {
    eventQueue.onFlush = { [weak self] events in
      guard let self = self else { return }

      let (userId, networkService) = self.synchronized { (self._userId, self.networkService) }
      guard let userId = userId, let networkService = networkService else { return }

      networkService.sendEvents(
        firebaseAppId: userId,
        events: events
      ) { result in
        switch result {
        case .success:
#if DEBUG
          debugPrint("[Hamon] ✅ Sent \(events.count) events successfully")
#endif
        case .failure(let error):
#if DEBUG
          debugPrint("[Hamon] ❌ Error sending events: \(error.localizedDescription)")
#endif
        }
      }
    }
  }

  private func updateUserDataSync() {
    let snapshot = synchronized {
      (
        userId: _userId,
        networkService: networkService,
        fcmToken: fcmToken,
        affiseID: affiseID,
        promoCode: promoCode,
        webCustomerID: webCustomerID,
        gdprConsentStatus: gdprConsentStatus,
        appsflyerId: appsflyerId
      )
    }

    guard let userId = snapshot.userId, let networkService = snapshot.networkService else {
      return
    }

    guard let appleId = deviceInfoService.getAppleId() else {
#if DEBUG
      debugPrint("[Hamon] ❌ Skipping user data update: AppStoreID is not configured in Info.plist")
#endif
      return
    }
#if DEBUG
    debugPrint("[Hamon] ℹ️ User ID: \(userId)")
#endif
    // Current timestamp in milliseconds
    let nowMillis = Int(Date().timeIntervalSince1970 * 1000)

    // appFirstOpenTimestamp
    let firstOpenTimestamp = storage.integer(for: .firstOpenTimestamp)
    if firstOpenTimestamp == 0 {
      storage.set(nowMillis, for: .firstOpenTimestamp)
    }

    let storageBytes = deviceInfoService.getStorageBytes()

    let userData = HUserData(
      package: appleId,
      appFirstOpenTimestamp: firstOpenTimestamp != 0 ? firstOpenTimestamp : nowMillis,
      appLastUpdateTimestamp: nowMillis,
      firebaseToken: snapshot.fcmToken,
      geo: deviceInfoService.getCountryCode(),
      osVersion: deviceInfoService.getOSVersion(),
      device: nil,
      deviceModel: deviceInfoService.getDevice(),
      appVersion: deviceInfoService.getAppVersion(),
      referrer: nil,
      tenjinAnalyticsInstallationId: nil,
      isLimitedAdTracking: deviceInfoService.isLimitedAdTracking(),
      advertisingId: deviceInfoService.getAdvertisingId(),
      appVersionCode: deviceInfoService.getAppVersionCode(),
      buildId: deviceInfoService.getBuildId(),
      locale: deviceInfoService.getLocale(),
      hints: nil,
      affiseID: snapshot.affiseID,
      promoCode: snapshot.promoCode,
      webCustomerID: snapshot.webCustomerID,
      connectionType: connectivityService.getConnectionType(),
      screenResolution: deviceInfoService.screenResolution,
      ramTotalBytes: deviceInfoService.getRamTotalBytes(),
      manufacturer: HamonConstants.manufacturer,
      brand: HamonConstants.brand,
      storageTotal: storageBytes.total,
      storageFree: storageBytes.free,
      gdprConsentStatus: snapshot.gdprConsentStatus ?? GdprConsent.unknown.rawValue,
      hamonVersion: HamonConstants.libVersion,
      timeToPaywall: paywallTracker.timeToPaywall,
      actionsBeforePaywall: paywallTracker.actionsBeforePaywall,
      intersShownBeforePaywall: paywallTracker.intersShownBeforePaywall,
      aoaShownBeforePaywall: paywallTracker.aoaShownBeforePaywall,
      paywallConversionTime: paywallTracker.paywallConversionTime,
      clickToPayTime: paywallTracker.clickToPayTime,
      sessionLengthFirst: sessionTracker.sessionLengthFirst,
      tapsCountFirst30s: sessionTracker.tapsCountFirst30s,
      appsflyerId: snapshot.appsflyerId
    )

    networkService.updateUser(firebaseAppId: userId, userData: userData) { result in
      switch result {
      case .success:
#if DEBUG
        debugPrint("[Hamon] ✅ User data updated successfully")
#endif
      case .failure(let error):
#if DEBUG
        debugPrint("[Hamon] ❌ Error updating user data: \(error.localizedDescription)")
#endif
      }
    }
  }

}
