import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import Hamon

final class HamonTests: XCTestCase {

#if canImport(UIKit)
  /// Captured before any test runs, so the swizzle assertions don't depend on test order.
  private static var originalSendEventIMP: IMP?

  override class func setUp() {
    super.setUp()
    originalSendEventIMP = class_getMethodImplementation(
      UIWindow.self, #selector(UIWindow.sendEvent(_:))
    )
  }
#endif


  // MARK: - Encryption Tests
  func testEncryption() throws {
    let service = HEncryptionService()
    let message = "Hello, World!"
    
    let encrypted = service.encrypt(message: message)
    
    XCTAssertFalse(encrypted?.isEmpty ?? true)
    XCTAssertNotEqual(encrypted, message)
    
    XCTAssertNotNil(Data(base64Encoded: encrypted ?? ""))
  }
  
  func testEncryptionConsistency() throws {
    let service = HEncryptionService()
    let message = "Test message"
    
    let encrypted1 = service.encrypt(message: message)
    let encrypted2 = service.encrypt(message: message)
    
    /// Если  AES CBC **с фиксированным IV**, тест работает.
    /// Если IV случайный — нет.
    XCTAssertEqual(encrypted1, encrypted2)
  }
  
  func testEncryptionEmptyString() throws {
    let service = HEncryptionService()
    let encrypted = service.encrypt(message: "")
    
    XCTAssertFalse(encrypted?.isEmpty ?? true)
  }
  
  func testEncryptionUnicode() throws {
    let service = HEncryptionService()
    let message = "Success! 🎉"
    
    let encrypted = service.encrypt(message: message)
    XCTAssertFalse(encrypted?.isEmpty ?? true)
  }
  
  // MARK: - Models Tests
  func testAnalyticsEventCreation() {
    let event = HAnalyticsEvent(name: "test_event", parameters: ["key": "value"])
    
    XCTAssertEqual(event.name, "test_event")
    XCTAssertFalse(event.uuid.isEmpty)
    XCTAssertGreaterThan(event.timestamp, 0)
  }
  
  func testAnalyticsEventWithDifferentParameterTypes() {
    let parameters: [String: Any] = [
      "string": "value",
      "int": 42,
      "double": 3.14,
      "bool": true,
      "array": [1, 2, 3],
      "dict": ["nested": "value"]
    ]
    
    let event = HAnalyticsEvent(name: "complex_event", parameters: parameters)
    
    XCTAssertEqual(event.name, "complex_event")
    XCTAssertEqual(event.parameters.count, 6)
  }
  
  /// Every key `HUserData` is expected to put on the wire.
  ///
  /// Deliberately absent: `carrier`. iOS cannot collect it — `CTCarrier` is deprecated
  /// since iOS 16 and returns "--" from 16.4 on — so the key is omitted rather than faked.
  private static let expectedWireKeys: Set<String> = [
    "lib_id", "package", "app_first_open_timestamp", "app_last_update_timestamp",
    "app_delete_timestamp", "firebase_token", "geo", "os_version", "device",
    "device_model", "app_version", "referrer", "tenjin_analytics_installation_id",
    "is_limited_ad_tracking", "advertising_id", "os_version_int", "app_version_code",
    "build_id", "locale", "hints", "affise_clickid", "affise_promo_code",
    "web_customer_id", "connection_type", "screen_resolution", "ram_total_bytes",
    "manufacturer", "brand", "storage_total", "storage_free", "gdpr_consent_status",
    "hamon_version", "time_to_paywall", "actions_before_paywall",
    "inters_shown_before_paywall", "aoa_shown_before_paywall", "paywall_conversion_time",
    "click_to_pay_time", "session_length_first", "taps_count_first_30s", "appsflyer_id",
  ]

  private func makeUserData(
    package: String = "com.example.app",
    firebaseToken: String? = "fcm_token",
    geo: String? = "UA"
  ) -> HUserData {
    HUserData(
      package: package,
      appFirstOpenTimestamp: 1234567890000,
      appLastUpdateTimestamp: nil,
      firebaseToken: firebaseToken,
      geo: geo,
      osVersion: "16.0",
      device: "iPhone14,2",
      deviceModel: "iPhone",
      appVersion: "1.0.0",
      referrer: nil,
      tenjinAnalyticsInstallationId: nil,
      isLimitedAdTracking: false,
      advertisingId: "test-idfa",
      appVersionCode: 1,
      buildId: "20A123",
      locale: "en_US",
      hints: nil,
      affiseID: nil,
      promoCode: nil,
      webCustomerID: nil,
      connectionType: "wifi",
      screenResolution: "1179x2556",
      ramTotalBytes: 6_442_450_944,
      manufacturer: "Apple",
      brand: "Apple",
      storageTotal: 128_000_000_000,
      storageFree: 42_000_000_000,
      gdprConsentStatus: "unknown",
      hamonVersion: "1.1.0",
      timeToPaywall: 48_000,
      actionsBeforePaywall: 4,
      intersShownBeforePaywall: 1,
      aoaShownBeforePaywall: 2,
      paywallConversionTime: 3_500_000,
      clickToPayTime: 6,
      sessionLengthFirst: 12_345,
      tapsCountFirst30s: 7,
      appsflyerId: "1234567890-1234567"
    )
  }

  /// `HUserData.encode(to:)` is hand-written, so a property added to the struct and to
  /// `CodingKeys` but forgotten in the encoder silently never reaches the wire — with no
  /// compiler error. This test is the only thing standing between that mistake and prod.
  func testUserDataEncodesEveryExpectedKey() throws {
    let data = try JSONEncoder().encode(makeUserData())
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )

    XCTAssertEqual(Set(json.keys), Self.expectedWireKeys)
  }

  func testUserDataEncodesNullsExplicitly() throws {
    /// Unlike Android — where `JSONObject.put(key, null)` drops the key — iOS sends an
    /// explicit null so the payload always carries the full schema.
    let data = try JSONEncoder().encode(makeUserData(firebaseToken: nil, geo: nil))
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )

    XCTAssertTrue(json["firebase_token"] is NSNull)
    XCTAssertTrue(json["geo"] is NSNull)
    XCTAssertEqual(Set(json.keys), Self.expectedWireKeys)
  }

  func testUserDataDoesNotSendCarrier() throws {
    let data = try JSONEncoder().encode(makeUserData())
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )

    XCTAssertNil(json["carrier"])
  }

  func testUserDataEncoding() throws {
    let userData = makeUserData()

    let encoder = JSONEncoder()
    let data = try encoder.encode(userData)
    
    XCTAssertFalse(data.isEmpty)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(HUserData.self, from: data)
    
    XCTAssertEqual(decoded.package, "com.example.app")
    XCTAssertEqual(decoded.geo, "UA")
  }
  
  func testEventsBatchEncoding() throws {
    let events = [
      HAnalyticsEvent(name: "event1", parameters: ["param": "value1"]),
      HAnalyticsEvent(name: "event2", parameters: ["param": "value2"])
    ]
    
    let batch = EventsBatch(events: events)
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(batch)
    
    XCTAssertFalse(data.isEmpty)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(EventsBatch.self, from: data)
    
    XCTAssertEqual(decoded.events.count, 2)
    XCTAssertEqual(decoded.events[0].name, "event1")
  }
  
  // MARK: - AnyCodable Tests
  
  func testAnyCodableWithString() throws {
    let value = AnyCodable("test")
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    
    XCTAssertEqual(decoded.value as? String, "test")
  }
  
  func testAnyCodableWithNumber() throws {
    let value = AnyCodable(42)
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    
    XCTAssertEqual(decoded.value as? Int, 42)
  }
  
  func testAnyCodableWithBool() throws {
    let value = AnyCodable(true)
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    
    XCTAssertEqual(decoded.value as? Bool, true)
  }
  
  func testAnyCodableWithArray() throws {
    let value = AnyCodable([1, 2, 3])
    
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    
    let array = decoded.value as? [Any]
    XCTAssertNotNil(array)
    XCTAssertEqual(array?.count, 3)
  }
  
  func testAnyCodableWithDictionary() throws {
    let value = AnyCodable(["key": "value"])
    
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    
    let dict = decoded.value as? [String: Any]
    XCTAssertNotNil(dict)
    XCTAssertEqual(dict?["key"] as? String, "value")
  }
  
  // MARK: - Device Info Tests
  func testDeviceInfoService() {
    let service = HDeviceInfoService()
    
    XCTAssertNotNil(service.getBuildId())
    XCTAssertFalse(service.getLocale()?.isEmpty ?? true)
    XCTAssertFalse(service.getOSVersion()?.isEmpty ?? true)
    XCTAssertFalse(service.getDevice()?.isEmpty ?? true)
    XCTAssertFalse(service.getDeviceModel()?.isEmpty ?? true)
  }
  
  func testAppVersionRetrieval() {
    let service = HDeviceInfoService()
    let version = service.getAppVersion()
    
    /// На macOS (SPM тесты) bundle может быть пустым.
    XCTAssertTrue(version == nil || !version!.isEmpty)
  }
  
  func testAppleIdRetrieval() {
    let service = HDeviceInfoService()
    let appleId = service.getAppleId()

    /// В SPM тестах в Info.plist нет ключа AppStoreID, это норм
    XCTAssertTrue(appleId == nil || !appleId!.isEmpty)
  }
  
  // MARK: - Event Queue Tests
  func testEventQueueAddEvent() {
    let queue = HEventQueue()
    let expectation = XCTestExpectation(description: "Event added")
    
    queue.onFlush = { events in
      XCTAssertEqual(events.count, 1)
      expectation.fulfill()
    }
    
    let event = HAnalyticsEvent(name: "test", parameters: [:])
    queue.add(event: event)
    queue.flush()
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  func testEventQueueBatchFlush() {
    let queue = HEventQueue()
    let expectation = XCTestExpectation(description: "Batch flushed")
    
    queue.onFlush = { events in
      XCTAssertEqual(events.count, 10)
      expectation.fulfill()
    }
    
    for i in 0..<10 {
      let event = HAnalyticsEvent(name: "event_\(i)", parameters: [:])
      queue.add(event: event)
    }
    
    wait(for: [expectation], timeout: 2.0)
  }
  
  func testEventQueueClear() {
    let queue = HEventQueue()
    var flushed = false
    
    queue.onFlush = { _ in flushed = true }
    
    queue.add(event: HAnalyticsEvent(name: "test", parameters: [:]))
    queue.clear()
    
    Thread.sleep(forTimeInterval: 0.1)
    
    XCTAssertFalse(flushed)
  }
  
  // MARK: - Integration Tests
  func testFullEventFlow() {
    let event = HAnalyticsEvent(
      name: "purchase",
      parameters: [
        "product_id": "premium",
        "price": 9.99,
        "currency": "USD"
      ]
    )
    
    XCTAssertEqual(event.name, "purchase")
    XCTAssertFalse(event.uuid.isEmpty)
    XCTAssertGreaterThan(event.timestamp, 0)
    XCTAssertEqual(event.parameters.count, 3)
  }
  
  func testEncryptedPayloadCreation() throws {
    let userData = makeUserData(package: "com.test", firebaseToken: nil)

    let json = String(data: try JSONEncoder().encode(userData), encoding: .utf8)!
    
    let encrypted = HEncryptionService().encrypt(message: json)
    
    let payload = EncryptedPayload(payload: encrypted ?? "")
    let data = try JSONEncoder().encode(payload)
    
    XCTAssertFalse(data.isEmpty)
    
    let decoded = try JSONDecoder().decode(EncryptedPayload.self, from: data)
    XCTAssertEqual(decoded.payload, encrypted)
  }

  // MARK: - appAccountToken Tests

  func testAppAccountTokenFromFirebaseAppInstanceId() {
    let token = Hamon.appAccountToken(from: "b9660c2a16297c54d42d5a3986c6e6c8")

    XCTAssertEqual(token?.uuidString.lowercased(), "b9660c2a-1629-7c54-d42d-5a3986c6e6c8")
  }

  func testAppAccountTokenIsReversibleToAppInstanceId() {
    let appInstanceId = "b9660c2a16297c54d42d5a3986c6e6c8"

    let token = Hamon.appAccountToken(from: appInstanceId)
    let stripped = token?.uuidString.lowercased().replacingOccurrences(of: "-", with: "")

    /// Бэкенд достаёт App Instance ID обратно простым удалением дефисов —
    /// символы меняться не должны.
    XCTAssertEqual(stripped, appInstanceId)
  }

  func testAppAccountTokenNormalizesInput() {
    let expected = "b9660c2a-1629-7c54-d42d-5a3986c6e6c8"

    XCTAssertEqual(
      Hamon.appAccountToken(from: "B9660C2A16297C54D42D5A3986C6E6C8")?.uuidString.lowercased(),
      expected
    )
    XCTAssertEqual(
      Hamon.appAccountToken(from: "  b9660c2a16297c54d42d5a3986c6e6c8\n")?.uuidString.lowercased(),
      expected
    )
  }

  func testAppAccountTokenRejectsWrongLength() {
    /// 31 символ
    XCTAssertNil(Hamon.appAccountToken(from: "b9660c2a16297c54d42d5a3986c6e6c"))
    /// 33 символа
    XCTAssertNil(Hamon.appAccountToken(from: "b9660c2a16297c54d42d5a3986c6e6c8a"))
    XCTAssertNil(Hamon.appAccountToken(from: ""))
  }

  func testAppAccountTokenRejectsNonHex() {
    /// 'g' не hex
    XCTAssertNil(Hamon.appAccountToken(from: "g9660c2a16297c54d42d5a3986c6e6c8"))
    /// Уже дефисованная строка — 36 символов, длина не проходит
    XCTAssertNil(Hamon.appAccountToken(from: "b9660c2a-1629-7c54-d42d-5a3986c6e6c8"))
  }

  func testAppAccountTokenRejectsUnicodeHexLookalikes() {
    /// Character.isHexDigit пропустил бы fullwidth-цифры, а UUID(uuidString:) — нет.
    let fullwidth = String(repeating: "１", count: 32)

    XCTAssertEqual(fullwidth.count, 32)
    XCTAssertNil(Hamon.appAccountToken(from: fullwidth))
  }

  // MARK: - Storage Tests

  private func makeStorage(function: String = #function) throws -> HStorage {
    let suite = try XCTUnwrap(UserDefaults(suiteName: "HamonTests.\(function)"))
    let storage = HStorage(defaults: suite)
    storage.reset()
    return storage
  }

  func testStorageRoundTripsStrings() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    storage.set("fLbjRJ00:APA91b", for: .fcmToken)

    /// Новый инстанс поверх того же суита — имитация холодного старта.
    let reloaded = HStorage(defaults: try XCTUnwrap(UserDefaults(suiteName: "HamonTests.\(#function)")))
    XCTAssertEqual(reloaded.string(for: .fcmToken), "fLbjRJ00:APA91b")
  }

  func testStorageTreatsEmptyStringAsAbsent() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    storage.set("token", for: .fcmToken)
    storage.set("", for: .fcmToken)

    XCTAssertNil(storage.string(for: .fcmToken))
  }

  func testStorageClearsValueOnNil() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    storage.set("code", for: .promoCode)
    storage.set(nil, for: .promoCode)

    XCTAssertNil(storage.string(for: .promoCode))
  }

  func testStorageIntegerDefaultsToZero() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    XCTAssertEqual(storage.integer(for: .firstOpenTimestamp), 0)

    storage.set(1234567890000, for: .firstOpenTimestamp)
    XCTAssertEqual(storage.integer(for: .firstOpenTimestamp), 1234567890000)
  }

  func testStorageResetClearsEveryKey() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    HStorage.Key.allCases.forEach { storage.set("value", for: $0) }
    storage.reset()

    HStorage.Key.allCases.forEach { XCTAssertNil(storage.string(for: $0)) }
  }

  func testStorageOptionalIntegerDistinguishesZeroFromAbsent() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    /// Load-bearing for taps_count_first_30s: "no taps" must ship as 0, not as null.
    XCTAssertNil(storage.optionalInteger(for: .tapsCountFirst30s))

    storage.set(0, for: .tapsCountFirst30s)
    XCTAssertEqual(storage.optionalInteger(for: .tapsCountFirst30s), 0)
  }

  // MARK: - Device Collectors

  func testScreenResolutionFormat() throws {
    let resolution = try XCTUnwrap(HDeviceInfoService().screenResolution)

    XCTAssertNotNil(
      resolution.range(of: "^[1-9][0-9]*x[1-9][0-9]*$", options: .regularExpression),
      "Expected \"<width>x<height>\" in pixels, got \(resolution)"
    )
  }

  func testRamTotalBytes() throws {
    let ram = try XCTUnwrap(HDeviceInfoService().getRamTotalBytes())

    /// Bytes, not KB — anything sane is well past 256 MB.
    XCTAssertGreaterThan(ram, 256 * 1024 * 1024)
  }

  func testStorageBytes() throws {
    let bytes = HDeviceInfoService().getStorageBytes()

    let total = try XCTUnwrap(bytes.total)
    let free = try XCTUnwrap(bytes.free)
    XCTAssertGreaterThan(total, 0)
    XCTAssertGreaterThanOrEqual(free, 0)
    XCTAssertLessThanOrEqual(free, total)
  }

  func testConnectionTypeIsOneOfAndroidsThreeValues() {
    let type = HConnectivityService().getConnectionType()

    XCTAssertTrue(
      ["wifi", "cellular", "none"].contains(type),
      "connection_type must match Android's vocabulary, got \(type)"
    )
  }

  // MARK: - GDPR Consent

  func testGdprConsentAcceptsOnlyTheThreeBackendValues() {
    XCTAssertEqual(Hamon.GdprConsent(rawValue: "accepted"), .accepted)
    XCTAssertEqual(Hamon.GdprConsent(rawValue: "rejected"), .rejected)
    XCTAssertEqual(Hamon.GdprConsent(rawValue: "unknown"), .unknown)

    /// Case-sensitive and closed, matching Android — invalid input is ignored, so the
    /// previously recorded decision survives rather than being overwritten with garbage.
    XCTAssertNil(Hamon.GdprConsent(rawValue: "Accepted"))
    XCTAssertNil(Hamon.GdprConsent(rawValue: "granted"))
    XCTAssertNil(Hamon.GdprConsent(rawValue: ""))
  }

  // MARK: - Paywall Funnel

  /// The tracker measures against `firstOpenTimestamp`, which `Hamon` stamps at startup.
  private func makePaywallTracker(
    firstOpenOffset: Int = -60_000,
    function: String = #function
  ) throws -> (HPaywallTracker, HStorage) {
    let storage = try makeStorage(function: function)
    let firstOpen = Int(Date().timeIntervalSince1970 * 1000) + firstOpenOffset
    storage.set(firstOpen, for: .firstOpenTimestamp)
    return (HPaywallTracker(storage: storage), storage)
  }

  func testPaywallOpenedFreezesCountersAndTime() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    XCTAssertNil(tracker.timeToPaywall)

    tracker.notifyUserAction()
    tracker.notifyUserAction()
    tracker.notifyInterstitialShown()
    tracker.notifyAoaShown()
    tracker.notifyAoaShown()
    tracker.notifyAoaShown()

    XCTAssertTrue(tracker.notifyPaywallOpened())

    XCTAssertEqual(tracker.actionsBeforePaywall, 2)
    XCTAssertEqual(tracker.intersShownBeforePaywall, 1)
    XCTAssertEqual(tracker.aoaShownBeforePaywall, 3)

    /// ~60 s of simulated time since first open, in milliseconds.
    let elapsed = try XCTUnwrap(tracker.timeToPaywall)
    XCTAssertGreaterThanOrEqual(elapsed, 60_000)
    XCTAssertLessThan(elapsed, 65_000)
  }

  func testPaywallOpenedIsLockedToTheFirstCall() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    XCTAssertTrue(tracker.notifyPaywallOpened())
    let locked = try XCTUnwrap(tracker.timeToPaywall)

    /// Counters after the freeze must not move the reported values.
    tracker.notifyUserAction()
    XCTAssertFalse(tracker.notifyPaywallOpened())

    XCTAssertEqual(tracker.timeToPaywall, locked)
    XCTAssertEqual(tracker.actionsBeforePaywall, 0)
  }

  func testZeroCountersShipAsZeroNotNull() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    tracker.notifyPaywallOpened()

    /// A genuine "user did nothing" must reach the backend as 0, never as null.
    XCTAssertEqual(tracker.actionsBeforePaywall, 0)
    XCTAssertEqual(tracker.intersShownBeforePaywall, 0)
    XCTAssertEqual(tracker.aoaShownBeforePaywall, 0)
  }

  func testPurchaseStartedRequiresAPaywall() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    XCTAssertFalse(tracker.notifyPurchaseStarted())
    XCTAssertNil(tracker.paywallConversionTime)

    /// No retro-fill: opening the paywall afterwards does not rescue the dropped signal.
    tracker.notifyPaywallOpened()
    XCTAssertNil(tracker.paywallConversionTime)
  }

  func testPurchaseCompletedRequiresAStartedPurchase() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    tracker.notifyPaywallOpened()
    XCTAssertFalse(tracker.notifyPurchaseCompleted())
    XCTAssertNil(tracker.clickToPayTime)
  }

  func testConversionTimeIsInMicroseconds() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    tracker.notifyPaywallOpened()
    Thread.sleep(forTimeInterval: 0.05)
    XCTAssertTrue(tracker.notifyPurchaseStarted())

    /// 50 ms is 50_000 µs — if this ever reads ~50, the unit regressed to milliseconds.
    let microseconds = try XCTUnwrap(tracker.paywallConversionTime)
    XCTAssertGreaterThanOrEqual(microseconds, 40_000)
    XCTAssertLessThan(microseconds, 2_000_000)
  }

  func testClickToPayTimeIsFlooredToWholeSeconds() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    tracker.notifyPaywallOpened()
    tracker.notifyPurchaseStarted()
    Thread.sleep(forTimeInterval: 0.05)
    XCTAssertTrue(tracker.notifyPurchaseCompleted())

    /// Whole seconds, floored — a sub-second billing flow reports 0, as on Android.
    XCTAssertEqual(tracker.clickToPayTime, 0)
  }

  func testFunnelSurvivesRelaunch() throws {
    let (tracker, storage) = try makePaywallTracker()
    defer { storage.reset() }

    tracker.notifyUserAction()
    tracker.notifyPaywallOpened()
    tracker.notifyPurchaseStarted()
    let conversion = try XCTUnwrap(tracker.paywallConversionTime)

    let reloaded = HPaywallTracker(storage: storage)
    XCTAssertEqual(reloaded.actionsBeforePaywall, 1)
    XCTAssertEqual(reloaded.paywallConversionTime, conversion)

    /// The funnel is closed — a fresh instance must not reopen it.
    XCTAssertFalse(reloaded.notifyPaywallOpened())
    XCTAssertFalse(reloaded.notifyPurchaseStarted())
  }

  func testTimeToPaywallStaysNilWithoutAFirstOpenBaseline() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let tracker = HPaywallTracker(storage: storage)
    XCTAssertTrue(tracker.notifyPaywallOpened())

    /// No baseline recorded, so the duration is unknown — but the funnel still opens and
    /// the counters still freeze.
    XCTAssertNil(tracker.timeToPaywall)
    XCTAssertEqual(tracker.actionsBeforePaywall, 0)
  }

  // MARK: - Session Tracker

#if canImport(UIKit)
  func testSessionTrackerMeasuresFirstForegroundSession() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let tracker = HSessionTracker(storage: storage)
    XCTAssertNil(tracker.sessionLengthFirst)

    let locked = expectation(description: "session length locked")
    tracker.onMetricLocked = { locked.fulfill() }
    tracker.start()

    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    Thread.sleep(forTimeInterval: 0.05)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

    wait(for: [locked], timeout: 1.0)
    XCTAssertGreaterThan(try XCTUnwrap(tracker.sessionLengthFirst), 0)
  }

  func testSessionTrackerLocksTheFirstSessionOnly() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let tracker = HSessionTracker(storage: storage)
    tracker.start()

    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    Thread.sleep(forTimeInterval: 0.05)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    let first = try XCTUnwrap(tracker.sessionLengthFirst)

    /// A longer second session must not overwrite the locked value.
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    Thread.sleep(forTimeInterval: 0.15)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

    XCTAssertEqual(tracker.sessionLengthFirst, first)
  }

  func testSessionTrackerSurvivesRelaunch() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let tracker = HSessionTracker(storage: storage)
    tracker.start()
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    Thread.sleep(forTimeInterval: 0.05)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    let measured = try XCTUnwrap(tracker.sessionLengthFirst)

    let reloaded = HSessionTracker(storage: storage)
    XCTAssertEqual(reloaded.sessionLengthFirst, measured)
  }

  func testTapsCountStaysNilWithoutOptIn() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let tracker = HSessionTracker(storage: storage, tapWindow: 0.1)
    tracker.start()
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    Thread.sleep(forTimeInterval: 0.3)

    /// Tap tracking swizzles UIWindow, so it stays off until the host opts in — and the
    /// window must not anchor and lock a bogus 0 in the meantime.
    XCTAssertNil(tracker.tapsCountFirst30s)
  }

  func testTapsAreCountedAndLockedAfterTheWindow() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let tracker = HSessionTracker(storage: storage, tapWindow: 0.2)
    let locked = expectation(description: "taps locked")
    tracker.onMetricLocked = { locked.fulfill() }
    tracker.start()
    tracker.enableTapTracking()

    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    (0..<3).forEach { _ in tracker.recordTap() }

    wait(for: [locked], timeout: 2.0)
    XCTAssertEqual(tracker.tapsCountFirst30s, 3)

    /// Taps after the window closes must not move the locked value.
    tracker.recordTap()
    XCTAssertEqual(tracker.tapsCountFirst30s, 3)
  }

  func testTapsBeforeOptInAreIgnored() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let tracker = HSessionTracker(storage: storage, tapWindow: 0.2)
    tracker.start()
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

    /// The swizzle is process-wide, so a tracker that was never opted in still receives
    /// taps from windows another tracker hooked. They must not be counted.
    (0..<5).forEach { _ in tracker.recordTap() }

    let locked = expectation(description: "taps locked")
    tracker.onMetricLocked = { locked.fulfill() }
    /// Opting in while the app is already foreground anchors the window immediately —
    /// the host may well call this after launch.
    tracker.enableTapTracking()
    tracker.recordTap()

    wait(for: [locked], timeout: 2.0)
    XCTAssertEqual(tracker.tapsCountFirst30s, 1)
  }

  func testEnableTapTrackingSwizzlesWindowSendEvent() throws {
    let storage = try makeStorage()
    defer { storage.reset() }

    let original = try XCTUnwrap(Self.originalSendEventIMP)

    /// Twice on purpose: `method_exchangeImplementations` is its own inverse, so a second
    /// swap would silently restore UIKit and disable tap counting.
    HSessionTracker(storage: storage).enableTapTracking()
    HSessionTracker(storage: storage).enableTapTracking()

    let current = class_getMethodImplementation(UIWindow.self, #selector(UIWindow.sendEvent(_:)))
    let trampoline = class_getMethodImplementation(
      UIWindow.self, NSSelectorFromString("hamon_sendEvent:")
    )

    XCTAssertNotEqual(current, original, "sendEvent: should now resolve to Hamon's implementation")
    XCTAssertEqual(
      trampoline, original,
      "hamon_sendEvent: must hold UIKit's original — otherwise every touch recurses"
    )
  }
#endif
}
