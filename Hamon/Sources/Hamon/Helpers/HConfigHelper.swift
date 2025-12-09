import Foundation

public final class HConfigHelper {
  
  // MARK: - ATS Warning
  
  /// Checks ATS configuration and prints warning if not set up correctly
  static func checkATSConfiguration(for serverIP: String, useHTTPS: Bool = false) {
    guard !useHTTPS else { return }
    
    // for http needs to setup ATS
    let isLocalhost = serverIP.contains("localhost") ||
    serverIP.contains("127.0.0.1") ||
    serverIP.hasPrefix("192.168.") ||
    serverIP.hasPrefix("10.")
    
    if !isLocalhost {
      printATSWarning(for: serverIP)
    }
  }
  
  private static func printATSWarning(for serverIP: String) {
    let cleanIP = serverIP
      .replacingOccurrences(of: "http://", with: "")
      .replacingOccurrences(of: "https://", with: "")
      .components(separatedBy: "/").first?
      .components(separatedBy: ":").first ?? serverIP
    
    debugPrint("""
        
        ⚠️ [Hamon] ATS CONFIGURATION REQUIRED ⚠️
        
        You are using HTTP connection to: \(cleanIP)
        
        Add this to your Info.plist to allow HTTP connections:
        
        <key>NSAppTransportSecurity</key>
        <dict>
            <key>NSExceptionDomains</key>
            <dict>
                <key>\(cleanIP)</key>
                <dict>
                    <key>NSExceptionAllowsInsecureHTTPLoads</key>
                    <true/>
                </dict>
            </dict>
        </dict>
        
        Or use HTTPS by setting useHTTPS: true in configure()
        
        """)
  }
  
  // MARK: - Connection Test
  
  /// Testing host connection
  static func testConnection(to baseURL: String, completion: @escaping (Bool, String) -> Void) {
    guard let url = URL(string: "\(baseURL)") else {
      completion(false, "Invalid URL")
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 5
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      DispatchQueue.main.async {
        if let error = error {
          let errorMessage: String
          if (error as NSError).code == -1022 {
            errorMessage = "ATS blocks HTTP connection. Configure Info.plist or use HTTPS."
          } else {
            errorMessage = error.localizedDescription
          }
          completion(false, errorMessage)
          return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
          let success = (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 404
          let message = success ? "Server reachable" : "Server returned status \(httpResponse.statusCode)"
          completion(success, message)
        } else {
          completion(false, "Invalid response")
        }
      }
    }
    
    task.resume()
  }
  
  // MARK: - Info.plist Helper
  
  /// Generates XML for Info.plist setup
  static func generateInfoPlistXML(for serverIP: String) -> String {
    let cleanIP = serverIP
      .replacingOccurrences(of: "http://", with: "")
      .replacingOccurrences(of: "https://", with: "")
      .components(separatedBy: "/").first?
      .components(separatedBy: ":").first ?? serverIP
    
    return """
        <key>NSAppTransportSecurity</key>
        <dict>
            <key>NSExceptionDomains</key>
            <dict>
                <key>\(cleanIP)</key>
                <dict>
                    <key>NSExceptionAllowsInsecureHTTPLoads</key>
                    <true/>
                </dict>
            </dict>
        </dict>
        """
  }
}
