import XCTest
@testable import Hamon

final class HamonTests: XCTestCase {
  
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
  
  func testUserDataEncoding() throws {
    let userData = HUserData(
      package: "com.example.app",
      appFirstOpenTimestamp: 1234567890000,
      appLastUpdateTimestamp: nil,
      firebaseToken: "fcm_token",
      geo: "UA",
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
      hints: nil
    )
    
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
  
  func testPackageNameRetrieval() {
    let service = HDeviceInfoService()
    let packageName = service.getPackageName()
    
    /// В SPM тестах Bundle.main.bundleIdentifier == nil, это норм
    XCTAssertTrue(packageName == nil || !packageName!.isEmpty)
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
    let userData = HUserData(
      package: "com.test",
      appFirstOpenTimestamp: nil,
      appLastUpdateTimestamp: nil,
      firebaseToken: nil,
      geo: "UA",
      osVersion: "16.0",
      device: "iPhone",
      deviceModel: "iPhone 14",
      appVersion: "1.0",
      referrer: nil,
      tenjinAnalyticsInstallationId: nil,
      isLimitedAdTracking: false,
      advertisingId: "test",
      appVersionCode: 1,
      buildId: "123",
      locale: "en_US",
      hints: nil
    )
    
    let json = String(data: try JSONEncoder().encode(userData), encoding: .utf8)!
    
    let encrypted = HEncryptionService().encrypt(message: json)
    
    let payload = EncryptedPayload(payload: encrypted ?? "")
    let data = try JSONEncoder().encode(payload)
    
    XCTAssertFalse(data.isEmpty)
    
    let decoded = try JSONDecoder().decode(EncryptedPayload.self, from: data)
    XCTAssertEqual(decoded.payload, encrypted)
  }
}
