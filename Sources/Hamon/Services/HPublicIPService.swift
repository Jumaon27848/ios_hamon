import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// The device's public addresses as ipify sees them, reported as `reported_ipv4` and
/// `reported_ipv6`.
///
/// Each family has its own single-stack host — `api.ipify.org` answers over IPv4 only,
/// `api6.ipify.org` over IPv6 only — so on a network without IPv6 the second request
/// simply fails and `reported_ipv6` goes out as null. Asked afresh for every PATCH: the
/// address follows the network, and a cached one would be stale after a Wi-Fi → cellular
/// switch.
final class HPublicIPService {

  enum Family {
    case ipv4
    case ipv6
  }

  static let ipv4URL = URL(string: "https://api.ipify.org")!
  static let ipv6URL = URL(string: "https://api6.ipify.org")!

  private let session: URLSession
  private let timeout: TimeInterval

  init(timeout: TimeInterval = 5) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.waitsForConnectivity = false
    self.session = URLSession(configuration: configuration)
    self.timeout = timeout
  }

  deinit {
    session.invalidateAndCancel()
  }

  /// Queries both families in parallel and blocks until both answer or `timeout` runs
  /// out. Never call on the main thread. A family that doesn't answer, answers with an
  /// error status, or answers with something that isn't an address (a captive portal
  /// page) comes back `nil`.
  func fetch() -> (ipv4: String?, ipv6: String?) {
    let lock = NSLock()
    var ipv4: String?
    var ipv6: String?
    let group = DispatchGroup()

    for (url, family) in [(Self.ipv4URL, Family.ipv4), (Self.ipv6URL, Family.ipv6)] {
      group.enter()
      let task = session.dataTask(with: url) { data, response, _ in
        defer { group.leave() }
        guard let status = (response as? HTTPURLResponse)?.statusCode,
              (200..<300).contains(status) else { return }
        let address = Self.parse(data, as: family)
        lock.lock()
        switch family {
        case .ipv4: ipv4 = address
        case .ipv6: ipv6 = address
        }
        lock.unlock()
      }
      task.resume()
    }

    // The session's own timeouts end both tasks; the margin only guards against a
    // completion handler that never fires.
    _ = group.wait(timeout: .now() + timeout + 1)

    lock.lock()
    defer { lock.unlock() }
#if DEBUG
    debugPrint("[Hamon] ℹ️ Public IP: v4=\(ipv4 ?? "nil") v6=\(ipv6 ?? "nil")")
#endif
    return (ipv4, ipv6)
  }

  /// The body as an address of the given family, or `nil` when it isn't one.
  static func parse(_ data: Data?, as family: Family) -> String? {
    guard let data = data,
          let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty else {
      return nil
    }
    return isAddress(text, of: family) ? text : nil
  }

  private static func isAddress(_ text: String, of family: Family) -> Bool {
    switch family {
    case .ipv4:
      var address = in_addr()
      return inet_pton(AF_INET, text, &address) == 1
    case .ipv6:
      var address = in6_addr()
      return inet_pton(AF_INET6, text, &address) == 1
    }
  }
}
