import SwiftUI

struct RegisterView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var age = 18
    @State private var selectedGender = "male"
    @State private var country = "한국"
    
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    let genders = ["male", "female", "other", "prefer_not_to_say"]
    let countries = ["한국", "미국", "일본", "중국", "영국", "프랑스", "독일", "기타"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("계정 정보")) {
                    TextField("이메일", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("사용자명", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("비밀번호", text: $password)
                    
                    SecureField("비밀번호 확인", text: $confirmPassword)
                }
                
                Section(header: Text("프로필 정보")) {
                    TextField("표시 이름", text: $displayName)
                    
                    Stepper("나이: \(age)", value: $age, in: 18...100)
                    
                    Picker("성별", selection: $selectedGender) {
                        ForEach(genders, id: \.self) { gender in
                            Text(genderDisplay(gender)).tag(gender)
                        }
                    }
                    
                    Picker("국가", selection: $country) {
                        ForEach(countries, id: \.self) { country in
                            Text(country).tag(country)
                        }
                    }
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: registerAction) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("가입 중...")
                            }
                        } else {
                            Text("회원가입")
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .navigationTitle("회원가입")
            .navigationBarItems(
                leading: Button("취소") { dismiss() }
            )
        }
    }
    
    private func genderDisplay(_ gender: String) -> String {
        switch gender {
        case "male": return "남성"
        case "female": return "여성"  
        case "other": return "기타"
        case "prefer_not_to_say": return "밝히지 않음"
        default: return gender.capitalized
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        !displayName.isEmpty &&
        password == confirmPassword &&
        password.count >= 8
    }
    
    private func registerAction() {
        guard isFormValid else {
            errorMessage = "모든 필드를 올바르게 입력해주세요."
            return
        }
        
        if password != confirmPassword {
            errorMessage = "비밀번호가 일치하지 않습니다."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authManager.register(
                    email: email,
                    username: username,
                    password: password,
                    displayName: displayName,
                    age: age,
                    gender: selectedGender,
                    country: country
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}