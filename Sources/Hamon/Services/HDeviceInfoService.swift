import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AdSupport)
import AdSupport
#endif
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(CoreTelephony)
import CoreTelephony
#endif

final class HDeviceInfoService {
  
  // MARK: - Device Info
  
  func getPackageName() -> String? {
    return Bundle.main.bundleIdentifier
  }
  
  func getOSVersion() -> String? {
#if canImport(UIKit)
    return UIDevice.current.systemVersion
#else
    return ProcessInfo.processInfo.operatingSystemVersionString
#endif
  }
  
  func getDevice() -> String? {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
  }
  
  func getDeviceModel() -> String? {
#if canImport(UIKit)
    return UIDevice.current.model
#else
    return "Unknown"
#endif
  }
  
  func getAppVersion() -> String? {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  }
  
  func getAppVersionCode() -> Int? {
    guard let versionString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
          let versionCode = Int(versionString) else {
      return nil
    }
    return versionCode
  }
  
  func getBuildId() -> String? {
    var size: size_t = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 else {
      return nil
    }
    
    return String(cString: buffer)
  }
  
  func getLocale() -> String? {
    return Locale.current.identifier
  }
  
  // MARK: - Advertising & Tracking
  
  func isLimitedAdTracking() -> Bool? {
#if canImport(AppTrackingTransparency)
    if #available(iOS 14, *) {
      return ATTrackingManager.trackingAuthorizationStatus != .authorized
    }
#endif
    
#if canImport(AdSupport)
    return ASIdentifierManager.shared().isAdvertisingTrackingEnabled == false
#else
    return nil
#endif
  }
  
  func getAdvertisingId() -> String? {
#if canImport(AppTrackingTransparency)
    if #available(iOS 14, *) {
      guard ATTrackingManager.trackingAuthorizationStatus == .authorized else {
        return getIDFV()
      }
    }
#endif
    
#if canImport(AdSupport)
    let idfa = ASIdentifierManager.shared().advertisingIdentifier
    
    if idfa.uuidString == "00000000-0000-0000-0000-000000000000" {
      return getIDFV()
    }
    
    return idfa.uuidString
#else
    return getIDFV()
#endif
  }
  
  private func getIDFV() -> String? {
#if canImport(UIKit)
    return UIDevice.current.identifierForVendor?.uuidString
#else
    return nil
#endif
  }
  
  @available(iOS 14, *)
  func requestTrackingAuthorization(completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
#if canImport(AppTrackingTransparency)
    ATTrackingManager.requestTrackingAuthorization { status in
      DispatchQueue.main.async {
        completion(status)
      }
    }
#endif
  }
  
  func getCountryCode() -> String? {
    // 1. Device locale
    if let regionCode = Locale.current.regionCode {
      return regionCode.uppercased()
    }
#if canImport(CoreTelephony)
    // 2. Carrier SIM region
    let networkInfo = CTTelephonyNetworkInfo()
    
    if #available(iOS 12.0, *) {
      if let carrier = networkInfo.serviceSubscriberCellularProviders?.values.first,
         let iso = carrier.isoCountryCode
      {
        return iso.uppercased()
      }
    } else {
      if let carrier = networkInfo.subscriberCellularProvider,
         let iso = carrier.isoCountryCode
      {
        return iso.uppercased()
      }
    }
    #else
    return nil
    #endif
    return nil
  }
}
