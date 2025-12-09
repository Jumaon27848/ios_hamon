#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
public extension View {
  func trackScreenView(name: String, parameters: [String: Any] = [:]) -> some View {
    self.onAppear {
      Hamon.shared.logEvent(name, parameters: parameters)
    }
  }
}
#endif

// Async/await for iOS 15+ (optional)
#if swift(>=5.5)
@available(iOS 15.0, *)
public extension Hamon {
  func testConnection(host: String) async -> (success: Bool, message: String) {
    await withCheckedContinuation { continuation in
      testConnection(host: host) { success, message in
        continuation.resume(returning: (success, message))
      }
    }
  }
}
#endif
