import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingRegister = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo or App Name
                Text("Topology")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                
                VStack(spacing: 15) {
                    // Username/Email field
                    TextField("Username or Email", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    // Error message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Login button
                    Button(action: loginAction) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Login")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    
                    // Register link
                    Button(action: { showingRegister = true }) {
                        Text("Don't have an account? Register")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
        }
    }
    
    private func loginAction() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                print("Starting login process...")
                print("Username: \(username)")
                print("Password provided: \(!password.isEmpty)")
                
                try await authManager.signIn(username: username, password: password)
                
                print("Login successful! User authenticated.")
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                print("Login error: \(error)")
                print("Error type: \(type(of: error))")
                print("Full error description: \(String(describing: error))")
                
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}