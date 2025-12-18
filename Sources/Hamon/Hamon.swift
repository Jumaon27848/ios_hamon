import Foundation

public final class Hamon {
  
  // MARK: - Singleton
  public static let shared = Hamon()
  
  // MARK: - Properties
  private var isInitialized = false
  private var baseURL: String?
  private var userId: String?
  private var fcmToken: String?
  private var affiseID: String?
  private var promoCode: String?
  
  private let deviceInfoService = HDeviceInfoService()
  private let encryptionService = HEncryptionService()
  private let eventQueue = HEventQueue()
  
  private var networkService: HNetworkService?
  
  private init() {
    setupEventQueueCallback()
  }
  
  // MARK: - Configuration
  
  /// Configure SDK with server IP
  /// - Parameters:
  ///   - host: Server IP address (e.g., "192.168.1.100" or "your.domain.com" for https)
  ///   - useHTTPS: Use HTTPS protocol (default: false)
  ///   - userId: Optional user identifier (Only if using custom user id instead of Firebase App Instance ID)
  public func configure(host: String, useHTTPS: Bool = false, userId: String? = nil) {
    self.baseURL = host
    guard let baseURL else { return }
    
    HConfigHelper.checkATSConfiguration(for: baseURL, useHTTPS: useHTTPS)
    
    self.networkService = HNetworkService(
      serverIP: baseURL,
      useHTTPS: useHTTPS,
      encryptionService: encryptionService
    )
    
    if let userId = userId {
      self.setUserId(userId)
    } else {
#if DEBUG
      debugPrint("[Hamon] ⚠️ Waiting for userId (Firebase App Instance ID preffered)")
#endif
    }
    
    self.isInitialized = true
  }
  
  // MARK: - Set userId externally
  
  /// Set user ID (Firebase App Instance ID recommended)
  public func setUserId(_ userId: String) {
    self.userId = userId
#if DEBUG
    debugPrint("[Hamon] ✅ userId set: \(userId)")
#endif
    // update user data on server
    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?.updateUserDataSync()
    }
  }
  
  // MARK: - Set affise id
  
  /// Set Affise ID (Affise Integration with click id)
  public func setAffiseId(_ id: String) {
    self.affiseID = id
#if DEBUG
    debugPrint("[Hamon] ✅ Affise ID set: \(id)")
#endif
    // update user data on server
    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?.updateUserDataSync()
    }
  }
  
  // MARK: - Set FCM Token
  
  /// Set Firebase Cloud Messaging token
  public func setFCM(token: String) {
    self.fcmToken = token
    // update user data on server
    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?.updateUserDataSync()
    }
  }
  
  // MARK: - Set Promo Code
  public func setPromoCode(_ code: String) {
    self.promoCode = code
    // update user data on server
    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?.updateUserDataSync()
    }
  }
  
  // MARK: - Event Tracking
  
  /// Log analytics event
  /// - Parameters:
  ///   - name: Event name
  ///   - parameters: Event parameters (optional)
  public func logEvent(_ name: String, parameters: [String: Any] = [:]) {
    guard isInitialized else {
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
  
  // MARK: - Private Methods
  
  private func setupEventQueueCallback() {
    eventQueue.onFlush = { [weak self] events in
      guard let self = self,
            let userId = self.userId,
            let networkService = self.networkService else {
        return
      }
      
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
    guard let userId = userId, let networkService = networkService else { return }
#if DEBUG
    debugPrint("[Hamon] ℹ️ User ID: \(userId)")
#endif
    // Current timestamp in milliseconds
    let nowMillis = Int(Date().timeIntervalSince1970 * 1000)
    
    // appFirstOpenTimestamp
    let firstOpenTimestamp = UserDefaults.standard.integer(forKey: "Hamon_firstOpenTimestamp")
    if firstOpenTimestamp == 0 {
      UserDefaults.standard.set(nowMillis, forKey: "Hamon_firstOpenTimestamp")
    }
    
    let userData = HUserData(
      package: deviceInfoService.getPackageName(),
      appFirstOpenTimestamp: firstOpenTimestamp != 0 ? firstOpenTimestamp : nowMillis,
      appLastUpdateTimestamp: nowMillis,
      firebaseToken: fcmToken,
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
      affiseID: affiseID,
      promoCode: promoCode
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
