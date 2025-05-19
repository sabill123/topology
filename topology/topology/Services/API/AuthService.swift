import Foundation

class AuthService {
    static let shared = AuthService()
    private let apiClient = APIClient.shared
    
    private init() {}
    
    // MARK: - Registration
    
    func register(
        email: String,
        username: String,
        password: String,
        displayName: String,
        age: Int,
        gender: String,
        country: String,
        bio: String? = nil,
        profileImageUrl: String? = nil,
        preferredGender: String? = nil,
        preferredAgeMin: Int = 18,
        preferredAgeMax: Int = 100,
        isProfilePublic: Bool = true,
        allowRandomCalls: Bool = true
    ) async throws -> User {
        let body = RegisterRequest(
            email: email,
            username: username,
            password: password,
            displayName: displayName,
            age: age,
            gender: gender,
            country: country,
            bio: bio,
            profileImageUrl: profileImageUrl,
            preferredGender: preferredGender,
            preferredAgeMin: preferredAgeMin,
            preferredAgeMax: preferredAgeMax,
            isProfilePublic: isProfilePublic,
            allowRandomCalls: allowRandomCalls
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(body)
        
        // 디버깅을 위한 로그
        print("Sending registration data:")
        print(String(data: data, encoding: .utf8) ?? "Unable to print data")
        
        // Configure decoder with custom date handling
        let customSession = URLSession.shared
        guard let url = URL(string: "http://172.30.1.87:8080/api/auth/register") else {
            throw APIClient.APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (responseData, _) = try await customSession.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ssZ"
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        let response = try decoder.decode(AuthResponse.self, from: responseData)
        
        // Save tokens
        UserDefaults.standard.set(response.accessToken, forKey: "accessToken")
        if let refreshToken = response.refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
        }
        
        return response.user
    }
    
    // MARK: - Login
    
    func login(username: String, password: String) async throws -> User {
        print("AuthService: Starting login...")
        
        // Form URL encoded data for OAuth2 compatibility
        let formData = "username=\(username)&password=\(password)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .data(using: .utf8)
        
        print("AuthService: Form data prepared")
        
        guard let url = URL(string: "http://172.30.1.87:8080/api/auth/login") else {
            throw APIClient.APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formData
        
        print("AuthService: Sending request to \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("AuthService: Response received")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClient.APIError.serverError("Invalid response")
        }
        
        print("AuthService: HTTP Status Code: \(httpResponse.statusCode)")
        print("AuthService: Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIClient.APIError.serverError("Login failed with status: \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Custom date decoder to handle multiple formats
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with microseconds
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // Try different formats
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ssZ"
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        do {
            let authResponse = try decoder.decode(LoginResponse.self, from: data)
            print("AuthService: Successfully decoded LoginResponse")
            print("AuthService: User ID: \(authResponse.user.id)")
            print("AuthService: User email: \(authResponse.user.email)")
            
            // Save tokens
            UserDefaults.standard.set(authResponse.accessToken, forKey: "accessToken")
            UserDefaults.standard.set(authResponse.refreshToken, forKey: "refreshToken")
            
            print("AuthService: Tokens saved to UserDefaults")
            
            // Update APIClient with tokens
            apiClient.setTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
            
            print("AuthService: APIClient tokens updated")
            
            // Return the user from the response
            return authResponse.user
        } catch {
            print("AuthService: Decoding error: \(error)")
            print("AuthService: Error type: \(type(of: error))")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key), context: \(context)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: \(type), context: \(context)")
                case .valueNotFound(let type, let context):
                    print("Value not found: \(type), context: \(context)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    // MARK: - Logout
    
    func logout() async throws {
        let _: EmptyResponse = try await apiClient.request(
            "/auth/logout",
            method: "POST",
            authenticated: true
        )
        
        // Clear tokens
        apiClient.clearTokens()
        
        // Clear user data
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
    
    // MARK: - Get Current User
    
    func getCurrentUser() async throws -> User {
        return try await apiClient.request("/auth/me", authenticated: true)
    }
    
    // MARK: - Password Reset
    
    func requestPasswordReset(email: String) async throws {
        let body = try JSONEncoder().encode(["email": email])
        
        let _: EmptyResponse = try await apiClient.request(
            "/auth/forgot-password",
            method: "POST",
            body: body,
            authenticated: false
        )
    }
    
    func resetPassword(token: String, newPassword: String) async throws {
        let body = PasswordResetConfirm(resetToken: token, newPassword: newPassword)
        let data = try JSONEncoder().encode(body)
        
        let _: EmptyResponse = try await apiClient.request(
            "/auth/reset-password",
            method: "POST",
            body: data,
            authenticated: false
        )
    }
}

// MARK: - Request/Response Models

struct RegisterRequest: Codable {
    let email: String
    let username: String
    let password: String
    let displayName: String
    let age: Int
    let gender: String
    let country: String
    let bio: String?
    let profileImageUrl: String?
    let preferredGender: String?
    let preferredAgeMin: Int
    let preferredAgeMax: Int
    let isProfilePublic: Bool
    let allowRandomCalls: Bool
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let user: User
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let user: User
}

struct PasswordResetConfirm: Codable {
    let resetToken: String
    let newPassword: String
}

struct EmptyResponse: Codable {}

// MARK: - User Model

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let username: String
    let displayName: String
    let age: Int?
    let gender: String?
    let country: String?
    let bio: String?
    let interests: [String]?
    let profileImageUrl: String?
    let photos: [String]?
    let location: Location?
    let status: String?
    let accountType: String?
    let role: String?
    let gems: Int?
    let lastSeen: Date?
    let isVerified: Bool?
    let isActive: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    let preferredGender: String?
    let preferredAgeMin: Int?
    let preferredAgeMax: Int?
    let isProfilePublic: Bool?
    let allowRandomCalls: Bool?
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double
}