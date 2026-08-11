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
  
  func getAppleId() -> String? {
    guard let appleId = Bundle.main.infoDictionary?["AppStoreID"] as? String, !appleId.isEmpty else {
#if DEBUG
      debugPrint("[Hamon] ❌ AppStoreID is not set in Info.plist. User data will not be sent to the server.")
#endif
      return nil
    }
    return appleId
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

  // MARK: - Hardware

  /// Screen size in physical pixels, `"<width>x<height>"`.
  ///
  /// `nativeBounds` is always portrait-referenced, so unlike Android — which reports the
  /// current rotation and flips to `"2340x1080"` in landscape — this value is stable for
  /// the lifetime of the device. Cached because it never changes and `UIScreen` is
  /// main-thread API, while the payload is assembled on a background queue.
  private(set) lazy var screenResolution: String? = {
#if canImport(UIKit)
    let pixels = UIScreen.main.nativeBounds
    let width = Int(pixels.width)
    let height = Int(pixels.height)
    guard width > 0, height > 0 else { return nil }
    return "\(width)x\(height)"
#else
    return nil
#endif
  }()

  /// Installed RAM in bytes.
  ///
  /// Note this is the full installed amount (exactly `4294967296` on a 4 GB device),
  /// whereas Android's `ActivityManager.MemoryInfo.totalMem` reports only what the kernel
  /// exposes (~3.7 GB). The two platforms' values are not directly comparable.
  func getRamTotalBytes() -> Int? {
    Int(exactly: ProcessInfo.processInfo.physicalMemory)
  }

  /// Total and available capacity of the volume backing the app, in bytes.
  ///
  /// Uses `volumeAvailableCapacityKey` rather than `volumeAvailableCapacityForImportantUsageKey`:
  /// the latter counts purgeable content as free and would report far more space than
  /// Android's `StatFs.availableBytes`, which excludes reserved blocks.
  func getStorageBytes() -> (total: Int?, free: Int?) {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    do {
      let values = try url.resourceValues(
        forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
      )
      return (values.volumeTotalCapacity, values.volumeAvailableCapacity)
    } catch {
#if DEBUG
      debugPrint("[Hamon] ⚠️ Failed to read storage info: \(error.localizedDescription)")
#endif
      return (nil, nil)
    }
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
