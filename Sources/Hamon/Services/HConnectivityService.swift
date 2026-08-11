import Foundation
#if canImport(Network)
import Network
#endif

/// Tracks the current network transport, reported as `connection_type`.
///
/// Emits exactly the three values Android emits — `"wifi"`, `"cellular"`, `"none"`.
/// Everything else (wired Ethernet, Bluetooth tethering, an unsatisfied path) collapses
/// to `"none"`, matching Android's `NetworkCapabilities` branch, which only tests for the
/// WIFI and CELLULAR transports.
final class HConnectivityService {

  enum ConnectionType: String {
    case wifi
    case cellular
    case none
  }

  private let lock = NSLock()
  private var currentType: ConnectionType = .none

#if canImport(Network)
  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "com.hamon.connectivity", qos: .utility)
#endif

  init() {
#if canImport(Network)
    // The monitor pushes updates, so reading the value at PATCH time is just a
    // lock-protected property read — no blocking syscall on the update queue.
    monitor.pathUpdateHandler = { [weak self] path in
      self?.update(with: path)
    }
    monitor.start(queue: monitorQueue)
    update(with: monitor.currentPath)
#endif
  }

  deinit {
#if canImport(Network)
    monitor.cancel()
#endif
  }

  /// Never nil — an unknown or absent connection reports `"none"`, as on Android.
  func getConnectionType() -> String {
    lock.lock()
    defer { lock.unlock() }
    return currentType.rawValue
  }

#if canImport(Network)
  private func update(with path: NWPath) {
    let type: ConnectionType
    if path.status != .satisfied {
      type = .none
    } else if path.usesInterfaceType(.wifi) {
      type = .wifi
    } else if path.usesInterfaceType(.cellular) {
      type = .cellular
    } else {
      type = .none
    }

    lock.lock()
    currentType = type
    lock.unlock()
  }
#endif
}
