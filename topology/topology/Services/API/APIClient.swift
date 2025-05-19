import Foundation
import Combine

class APIClient {
    static let shared = APIClient()
    
    private let baseURL = "http://172.30.1.87:8080/api"
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Token Management
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "accessToken") }
        set { UserDefaults.standard.set(newValue, forKey: "accessToken") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "refreshToken") }
        set { UserDefaults.standard.set(newValue, forKey: "refreshToken") }
    }
    
    // MARK: - Request Methods
    
    enum APIError: LocalizedError {
        case invalidURL
        case noData
        case decodingError
        case serverError(String)
        case unauthorized
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            case .decodingError:
                return "Failed to decode response"
            case .serverError(let message):
                return message
            case .unauthorized:
                return "Unauthorized access"
            case .networkError(let error):
                return error.localizedDescription
            }
        }
    }
    
    // MARK: - Generic Request Method
    
    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        authenticated: Bool = true,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            print("Making request to: \(url)")
            print("Method: \(method)")
            if let body = body {
                print("Body: \(String(data: body, encoding: .utf8) ?? "Unable to print body")")
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response body: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    
                    // 커스텀 날짜 포맷터 사용
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    // 여러 날짜 형식을 지원하는 커스텀 디코더
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        // 먼저 마이크로초 포함된 형식 시도
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                        
                        // 표준 ISO8601 형식 시도
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                        
                        // 밀리초 포함 형식 시도
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                        
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                    }
                    
                    return try decoder.decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw APIError.decodingError
                }
                
            case 400:
                // Handle bad request with details
                var errorMessage = "Bad Request"
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    errorMessage = detail
                }
                throw APIError.serverError(errorMessage)
                
            case 401:
                if retryOnUnauthorized, let refreshToken = refreshToken {
                    // Try to refresh token
                    try await refreshAccessToken(refreshToken)
                    // Retry the request
                    return try await self.request(
                        endpoint,
                        method: method,
                        body: body,
                        authenticated: authenticated,
                        retryOnUnauthorized: false
                    )
                } else {
                    throw APIError.unauthorized
                }
                
            case 422:
                // Handle validation error with more details
                var errorMessage = "Validation error"
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let detail = errorData["detail"] as? String {
                        errorMessage = detail
                    } else if let details = errorData["detail"] as? [[String: Any]] {
                        let messages = details.compactMap { dict -> String? in
                            if let loc = dict["loc"] as? [String],
                               let msg = dict["msg"] as? String {
                                return "\(loc.joined(separator: ".")): \(msg)"
                            }
                            return nil
                        }
                        errorMessage = messages.joined(separator: ", ")
                    }
                }
                throw APIError.serverError(errorMessage)
                
            case 500:
                // Handle internal server error with details
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    throw APIError.serverError("Internal Server Error: \(detail)")
                } else {
                    throw APIError.serverError("Internal Server Error")
                }
                
            default:
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    throw APIError.serverError(detail)
                } else {
                    throw APIError.serverError("Server error: \(httpResponse.statusCode)")
                }
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Multipart Form Data Request
    
    func uploadMultipartFormData<T: Decodable>(
        _ endpoint: String,
        formData: MultipartFormData,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = formData.encode(boundary: boundary)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Upload failed")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken(_ refreshToken: String) async throws {
        let endpoint = "/auth/refresh"
        let body = try JSONEncoder().encode(["refresh_token": refreshToken])
        
        let response: TokenResponse = try await request(
            endpoint,
            method: "POST",
            body: body,
            authenticated: false,
            retryOnUnauthorized: false
        )
        
        self.accessToken = response.accessToken
        if let newRefreshToken = response.refreshToken {
            self.refreshToken = newRefreshToken
        }
    }
    
    // MARK: - Clear Tokens
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }
    
    // MARK: - Set Tokens
    
    func setTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

// MARK: - Response Models

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let user: User?
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}

// MARK: - Multipart Form Data Helper

struct MultipartFormData {
    private var parts: [Part] = []
    
    struct Part {
        let name: String
        let data: Data
        let filename: String?
        let mimeType: String?
    }
    
    mutating func append(_ data: Data, withName name: String, fileName: String? = nil, mimeType: String? = nil) {
        parts.append(Part(name: name, data: data, filename: fileName, mimeType: mimeType))
    }
    
    func encode(boundary: String) -> Data {
        var data = Data()
        
        for part in parts {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            
            if let filename = part.filename, let mimeType = part.mimeType {
                data.append("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            } else {
                data.append("Content-Disposition: form-data; name=\"\(part.name)\"\r\n\r\n".data(using: .utf8)!)
            }
            
            data.append(part.data)
            data.append("\r\n".data(using: .utf8)!)
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
}