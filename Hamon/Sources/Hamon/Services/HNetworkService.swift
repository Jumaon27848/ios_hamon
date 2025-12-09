import Foundation

final class HNetworkService {
  
  private let baseURL: String
  private let encryptionService: HEncryptionService
  private let session: URLSession
  
  private static let apiVersion: String = "v1"
  
  init(serverIP: String, useHTTPS: Bool, encryptionService: HEncryptionService) {
    self.baseURL = HNetworkService.buildBaseURL(from: serverIP, useHTTPS: useHTTPS)
    self.encryptionService = encryptionService
    
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60
    self.session = URLSession(configuration: configuration)
  }
  
  // MARK: - URL Building
  
  static func buildBaseURL(from serverIP: String, useHTTPS: Bool) -> String {
    var cleanIP = serverIP.trimmingCharacters(in: .whitespaces)
    
    cleanIP = cleanIP.replacingOccurrences(of: "http://", with: "")
    cleanIP = cleanIP.replacingOccurrences(of: "https://", with: "")
    
    cleanIP = cleanIP.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    
    let protocol_prefix = useHTTPS ? "https://" : "http://"
    let fullURL = "\(protocol_prefix)\(cleanIP)/\(apiVersion)"
    
    return fullURL
  }
  
  // MARK: - User Update
  
  func updateUser(
    firebaseAppId: String,
    userData: HUserData,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let endpoint = "/users/\(firebaseAppId)"
    
    performRequest(
      endpoint: endpoint,
      method: "PATCH",
      body: userData,
      completion: completion
    )
  }
  
  // MARK: - Events
  
  func sendEvents(
    firebaseAppId: String,
    events: [HAnalyticsEvent],
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let endpoint = "/users/\(firebaseAppId)/event"
    let batch = EventsBatch(events: events)
    
    performRequest(
      endpoint: endpoint,
      method: "POST",
      body: batch,
      completion: completion
    )
  }
  
  // MARK: - Private Methods
  
  private func performRequest<T: Encodable>(
    endpoint: String,
    method: String,
    body: T,
    retryCount: Int = 0,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let url = URL(string: baseURL + endpoint) else {
      completion(.failure(NetworkError.invalidURL))
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      let jsonData = try encoder.encode(body)
      
      guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        completion(.failure(NetworkError.encodingFailed))
        return
      }
      
      guard let encryptedPayload = encryptionService.encrypt(message: jsonString) else {
        completion(.failure(NetworkError.encryptionFailed))
        return
      }
      
      let payload = EncryptedPayload(payload: encryptedPayload)
      let payloadData = try encoder.encode(payload)
      request.httpBody = payloadData
            
      let task = session.dataTask(with: request) { [weak self] data, response, error in
        if let error = error {
          completion(.failure(error))
          return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
          completion(.failure(NetworkError.invalidResponse))
          return
        }
        
        switch httpResponse.statusCode {
        case 200:
          completion(.success(()))
          
        case 422:
          if let data = data {
            self?.handleValidationError(data: data)
          }
          completion(.failure(NetworkError.validationError))
          
        case 500...599:
          if retryCount < 1 {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) {
              self?.performRequest(
                endpoint: endpoint,
                method: method,
                body: body,
                retryCount: retryCount + 1,
                completion: completion
              )
            }
          } else {
            completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
          }
          
        default:
          completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
        }
      }
      
      task.resume()
      
    } catch {
      completion(.failure(error))
    }
  }
  
  private func handleValidationError(data: Data) {
    do {
      let decoder = JSONDecoder()
      let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
#if DEBUG
      debugPrint("[Hamon.NetworkService] Validation errors:")
      for error in errorResponse.detail {
        debugPrint("[Hamon.NetworkService.ErrorDescription] - Field: \(error.loc.joined(separator: ".")), Message: \(error.msg)")
      }
#endif
    } catch {
#if DEBUG
      debugPrint("[Hamon.NetworkService] Failed to parse validation error: \(error)")
#endif
    }
  }
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError {
  case invalidURL
  case invalidResponse
  case encodingFailed
  case encryptionFailed
  case validationError
  case serverError(Int)
  
  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid URL"
    case .invalidResponse:
      return "Invalid response from server"
    case .encodingFailed:
      return "Failed to encode request data"
    case .encryptionFailed:
      return "Failed to encrypt payload"
    case .validationError:
      return "Validation error"
    case .serverError(let code):
      return "Server error with code: \(code)"
    }
  }
}
