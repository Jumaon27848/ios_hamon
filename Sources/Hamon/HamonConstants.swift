import Foundation

enum HamonConstants {
  /// Reported to the server as `hamon_version`.
  ///
  /// Keep in sync with the package's git tag — SPM exposes no runtime version API,
  /// so this constant is the only source of truth, exactly as `Constants.LIB_VERSION`
  /// is on Android.
  static let libVersion = "1.1.0"

  /// iOS has no manufacturer/brand distinction — Android separates them because one
  /// manufacturer ships several retail brands (Xiaomi → Redmi / POCO). Both are sent
  /// so the payload schema stays uniform across platforms.
  static let manufacturer = "Apple"
  static let brand = "Apple"
}
