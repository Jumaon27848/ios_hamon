import Foundation

// MARK: - User Data Models

public struct HUserData: Codable {
  public let libId: String? = nil
  public let package: String?
  public let appFirstOpenTimestamp: Int?
  public let appLastUpdateTimestamp: Int?
  public let appDeleteTimestamp: Int? = nil
  public let firebaseToken: String?
  public let geo: String?
  public let osVersion: String?
  public let device: String?
  public let deviceModel: String?
  public let appVersion: String?
  public let referrer: String?
  public let tenjinAnalyticsInstallationId: String?
  public let isLimitedAdTracking: Bool?
  public let advertisingId: String?
  public let osVersionInt: Int? = nil
  public let appVersionCode: Int?
  public let buildId: String?
  public let locale: String?
  public let hints: HUserHints?
  public let affiseID: String?
  public let promoCode: String?
  
  enum CodingKeys: String, CodingKey {
    case libId = "lib_id"
    case package
    case appFirstOpenTimestamp = "app_first_open_timestamp"
    case appLastUpdateTimestamp = "app_last_update_timestamp"
    case appDeleteTimestamp = "app_delete_timestamp"
    case firebaseToken = "firebase_token"
    case geo
    case osVersion = "os_version"
    case device
    case deviceModel = "device_model"
    case appVersion = "app_version"
    case referrer
    case tenjinAnalyticsInstallationId = "tenjin_analytics_installation_id"
    case isLimitedAdTracking = "is_limited_ad_tracking"
    case advertisingId = "advertising_id"
    case osVersionInt = "os_version_int"
    case appVersionCode = "app_version_code"
    case buildId = "build_id"
    case locale
    case hints
    case affiseID = "affise_clickid"
    case promoCode = "affise_promo_code"
  }
  
  // Кастомный энкодер, чтобы null явно отправлялся для всех Optional
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(libId, forKey: .libId)
    try container.encode(package, forKey: .package)
    try container.encode(appFirstOpenTimestamp, forKey: .appFirstOpenTimestamp)
    try container.encode(appLastUpdateTimestamp, forKey: .appLastUpdateTimestamp)
    try container.encode(appDeleteTimestamp, forKey: .appDeleteTimestamp)
    try container.encode(firebaseToken, forKey: .firebaseToken)
    try container.encode(geo, forKey: .geo)
    try container.encode(osVersion, forKey: .osVersion)
    try container.encode(device, forKey: .device)
    try container.encode(deviceModel, forKey: .deviceModel)
    try container.encode(appVersion, forKey: .appVersion)
    try container.encode(referrer, forKey: .referrer)
    try container.encode(tenjinAnalyticsInstallationId, forKey: .tenjinAnalyticsInstallationId)
    try container.encode(isLimitedAdTracking, forKey: .isLimitedAdTracking)
    try container.encode(advertisingId, forKey: .advertisingId)
    try container.encode(osVersionInt, forKey: .osVersionInt)
    try container.encode(appVersionCode, forKey: .appVersionCode)
    try container.encode(buildId, forKey: .buildId)
    try container.encode(locale, forKey: .locale)
    try container.encode(hints, forKey: .hints)
    try container.encode(affiseID, forKey: .affiseID)
    try container.encode(promoCode, forKey: .promoCode)
  }
}

public struct HUserHints: Codable {
  public let firstAppInstanceUpdate: Bool?
  public let oldData: [String: AnyCodable]?
  public let deviceTimestampMillis: Int?
  
  enum CodingKeys: String, CodingKey {
    case firstAppInstanceUpdate = "first_app_instance_update"
    case oldData = "old_data"
    case deviceTimestampMillis = "device_timestamp_millis"
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(firstAppInstanceUpdate, forKey: .firstAppInstanceUpdate)
    try container.encode(oldData, forKey: .oldData)
    try container.encode(deviceTimestampMillis, forKey: .deviceTimestampMillis)
  }
}

// MARK: - Event Models

public struct HAnalyticsEvent: Codable {
  public let uuid: String
  public let timestamp: Int
  public let name: String
  public let parameters: [String: AnyCodable]
  
  public init(name: String, parameters: [String: Any] = [:]) {
    self.uuid = UUID().uuidString
    self.timestamp = Int(Date().timeIntervalSince1970 * 1000)
    self.name = name
    self.parameters = parameters.mapValues { AnyCodable($0) }
  }
}

public struct EventsBatch: Codable {
  public let events: [HAnalyticsEvent]
}

// MARK: - Network Models

public struct EncryptedPayload: Codable {
  public let payload: String
}

public struct APIResponse: Codable {
  public let status: String
}

public struct ValidationError: Codable {
  public let loc: [String]
  public let msg: String
  public let type: String
}

public struct ErrorResponse: Codable {
  public let detail: [ValidationError]
}

// MARK: - AnyCodable

public struct AnyCodable: Codable {
  public let value: Any
  
  public init(_ value: Any) {
    self.value = value
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    
    if let intValue = try? container.decode(Int.self) {
      value = intValue
    } else if let doubleValue = try? container.decode(Double.self) {
      value = doubleValue
    } else if let boolValue = try? container.decode(Bool.self) {
      value = boolValue
    } else if let stringValue = try? container.decode(String.self) {
      value = stringValue
    } else if let arrayValue = try? container.decode([AnyCodable].self) {
      value = arrayValue.map { $0.value }
    } else if let dictValue = try? container.decode([String: AnyCodable].self) {
      value = dictValue.mapValues { $0.value }
    } else {
      value = NSNull()
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    
    switch value {
    case let intValue as Int:
      try container.encode(intValue)
    case let doubleValue as Double:
      try container.encode(doubleValue)
    case let boolValue as Bool:
      try container.encode(boolValue)
    case let stringValue as String:
      try container.encode(stringValue)
    case let arrayValue as [Any]:
      try container.encode(arrayValue.map { AnyCodable($0) })
    case let dictValue as [String: Any]:
      try container.encode(dictValue.mapValues { AnyCodable($0) })
    default:
      try container.encodeNil()
    }
  }
}
