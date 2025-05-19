import SwiftUI
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true
    
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Check Authentication Status
    
    func checkAuthStatus() {
        Task {
            isLoading = true
            
            // Check if we have an access token
            if UserDefaults.standard.string(forKey: "accessToken") != nil {
                do {
                    // Try to get current user
                    let user = try await authService.getCurrentUser()
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                    
                    // Connect WebSocket
                    WebSocketService.shared.connect()
                } catch {
                    print("Failed to get current user: \(error)")
                    await MainActor.run {
                        self.signOut()
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func signIn(username: String, password: String) async throws {
        print("AuthManager: Starting sign in...")
        do {
            let user = try await authService.login(username: username, password: password)
            print("AuthManager: Login service returned user: \(user.email)")
            
            await MainActor.run {
                print("AuthManager: Setting current user on MainActor")
                self.currentUser = user
                self.isAuthenticated = true
                print("AuthManager: User authenticated: \(self.isAuthenticated)")
            }
            
            print("AuthManager: Connecting WebSocket...")
            // Connect WebSocket
            WebSocketService.shared.connect()
            print("AuthManager: Sign in completed successfully")
        } catch {
            print("AuthManager: Sign in error: \(error)")
            throw error
        }
    }
    
    // MARK: - Register
    
    func register(
        email: String,
        username: String,
        password: String,
        displayName: String,
        age: Int,
        gender: String,
        country: String
    ) async throws {
        do {
            let user = try await authService.register(
                email: email,
                username: username,
                password: password,
                displayName: displayName,
                age: age,
                gender: gender,
                country: country,
                bio: nil,
                profileImageUrl: nil,
                preferredGender: nil,
                preferredAgeMin: 18,
                preferredAgeMax: 100,
                isProfilePublic: true,
                allowRandomCalls: true
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
            
            // Connect WebSocket
            WebSocketService.shared.connect()
        } catch {
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        Task {
            do {
                try await authService.logout()
            } catch {
                print("Logout error: \(error)")
            }
            
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                
                // Clear all stored data
                UserDefaults.standard.removeObject(forKey: "accessToken")
                UserDefaults.standard.removeObject(forKey: "refreshToken")
                
                // Disconnect WebSocket
                WebSocketService.shared.disconnect()
            }
        }
    }
}