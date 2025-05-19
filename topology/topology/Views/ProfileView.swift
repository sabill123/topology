import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @StateObject private var authManager = AuthManager.shared
    @State private var isEditMode = false
    @State private var showImagePicker = false
    @State private var showSettings = false
    @State private var showLogoutAlert = false
    @State private var showNotificationSettings = false
    @State private var showPrivacySettings = false
    @State private var showHelpCenter = false
    @State private var showContactUs = false
    @State private var showTermsOfService = false
    @State private var userProfile: User?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 프로필 헤더
                    ProfileHeaderView(
                        user: userProfile ?? authManager.currentUser,
                        isEditMode: $isEditMode,
                        showImagePicker: $showImagePicker
                    )
                    
                    // 프로필 통계
                    ProfileStatsView(viewModel: viewModel)
                    
                    // 메뉴 옵션들
                    VStack(spacing: 0) {
                        MenuSection(title: "계정") {
                            VStack(spacing: 0) {
                                ProfileMenuItem(
                                    icon: "person.fill",
                                    title: "내 정보 수정",
                                    action: { isEditMode = true }
                                )
                                
                                ProfileMenuItem(
                                    icon: "bell.fill",
                                    title: "알림 설정",
                                    action: { showNotificationSettings = true }
                                )
                                
                                ProfileMenuItem(
                                    icon: "lock.fill",
                                    title: "프라이버시",
                                    action: { showPrivacySettings = true }
                                )
                            }
                        }
                        
                        MenuSection(title: "활동") {
                            VStack(spacing: 0) {
                                NavigationLink(destination: MyItemsView(viewModel: viewModel)) {
                                    ProfileMenuItem(
                                        icon: "bag.fill",
                                        title: "내 아이템",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(destination: PurchaseHistoryView(viewModel: viewModel)) {
                                    ProfileMenuItem(
                                        icon: "clock.fill",
                                        title: "구매 내역",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(destination: PointHistoryView(viewModel: viewModel)) {
                                    ProfileMenuItem(
                                        icon: "diamond.fill",
                                        title: "포인트 내역",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        MenuSection(title: "지원") {
                            VStack(spacing: 0) {
                                ProfileMenuItem(
                                    icon: "questionmark.circle.fill",
                                    title: "도움말",
                                    action: { showHelpCenter = true }
                                )
                                
                                ProfileMenuItem(
                                    icon: "envelope.fill",
                                    title: "문의하기",
                                    action: { showContactUs = true }
                                )
                                
                                ProfileMenuItem(
                                    icon: "doc.text.fill",
                                    title: "이용약관",
                                    action: { showTermsOfService = true }
                                )
                            }
                        }
                        
                        MenuSection(title: "") {
                            VStack(spacing: 0) {
                                ProfileMenuItem(
                                    icon: "arrow.right.square.fill",
                                    title: "로그아웃",
                                    titleColor: .red,
                                    action: { showLogoutAlert = true }
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("프로필")
            .navigationBarItems(trailing: Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
            })
            .sheet(isPresented: $isEditMode) {
                ProfileEditView(user: userProfile ?? authManager.currentUser, onSave: { updatedUser in
                    userProfile = updatedUser
                })
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showPrivacySettings) {
                PrivacySettingsView()
            }
            .sheet(isPresented: $showHelpCenter) {
                HelpCenterView()
            }
            .sheet(isPresented: $showContactUs) {
                ContactUsView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("로그아웃"),
                    message: Text("정말 로그아웃 하시겠습니까?"),
                    primaryButton: .destructive(Text("로그아웃")) {
                        authManager.signOut()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
            .onAppear {
                loadUserProfile()
            }
        }
    }
    
    private func loadUserProfile() {
        Task {
            do {
                if let currentUser = authManager.currentUser {
                    userProfile = currentUser
                } else {
                    // If no cached user, try to fetch from server
                    let user = try await AuthService.shared.getCurrentUser()
                    await MainActor.run {
                        userProfile = user
                    }
                }
            } catch {
                print("Failed to load user profile: \(error)")
            }
        }
    }
}

// 프로필 헤더
struct ProfileHeaderView: View {
    let user: User?
    @Binding var isEditMode: Bool
    @Binding var showImagePicker: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // 프로필 이미지
            ZStack(alignment: .bottomTrailing) {
                if let profileImageUrl = user?.profileImageUrl, !profileImageUrl.isEmpty {
                    // TODO: AsyncImage for profile photo
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(String(user?.displayName.first ?? "?"))
                                .font(.system(size: 60))
                        )
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text("👤")
                                .font(.system(size: 60))
                        )
                }
                
                Button(action: {
                    showImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .offset(x: -5, y: -5)
            }
            
            // 사용자 정보
            VStack(spacing: 8) {
                Text(user?.displayName ?? "사용자")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    if let age = user?.age, let gender = user?.gender {
                        Text("\(age)세 • \(gender)")
                            .foregroundColor(.gray)
                    }
                    
                    if let country = user?.country {
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(country)
                            .foregroundColor(.gray)
                    }
                }
                
                if let bio = user?.bio, !bio.isEmpty {
                    Text(bio)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            // 프로필 편집 버튼
            Button(action: {
                isEditMode = true
            }) {
                Text("프로필 편집")
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 20)
    }
}

// 프로필 통계
struct ProfileStatsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            StatItem(title: "친구", value: "\(viewModel.friends.count)")
            
            Divider()
                .frame(height: 50)
                .background(Color.gray.opacity(0.3))
            
            StatItem(title: "보석", value: "\(viewModel.myGems)")
            
            Divider()
                .frame(height: 50)
                .background(Color.gray.opacity(0.3))
            
            StatItem(title: "통화 횟수", value: "\(viewModel.callRecords.count)")
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// 통계 아이템
struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// 메뉴 섹션
struct MenuSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            if !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// 프로필 메뉴 아이템
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    var titleColor: Color = .white
    var showChevron: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(titleColor == .red ? .red : .gray)
                    .frame(width: 30)
                
                Text(title)
                    .foregroundColor(titleColor)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
            .padding()
        }
    }
}

// 프로필 편집 뷰
struct ProfileEditView: View {
    let user: User?
    let onSave: (User) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var age: String = ""
    @State private var selectedGender: String = "male"
    @State private var country: String = ""
    @State private var preferredGender: String = "all"
    @State private var preferredAgeMin: String = "18"
    @State private var preferredAgeMax: String = "100"
    @State private var isProfilePublic: Bool = true
    @State private var allowRandomCalls: Bool = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let genders = ["male", "female", "other", "prefer_not_to_say"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("기본 정보")) {
                    TextField("표시 이름", text: $displayName)
                    TextField("소개", text: $bio)
                    TextField("나이", text: $age)
                        .keyboardType(.numberPad)
                    
                    Picker("성별", selection: $selectedGender) {
                        Text("남성").tag("male")
                        Text("여성").tag("female")
                        Text("기타").tag("other")
                        Text("밝히지 않음").tag("prefer_not_to_say")
                    }
                    
                    TextField("국가", text: $country)
                }
                
                Section(header: Text("프라이버시")) {
                    Toggle("프로필 공개", isOn: $isProfilePublic)
                    Toggle("랜덤 통화 허용", isOn: $allowRandomCalls)
                }
                
                Section(header: Text("선호 설정")) {
                    Picker("선호 성별", selection: $preferredGender) {
                        Text("모두").tag("all")
                        Text("남성").tag("male")
                        Text("여성").tag("female")
                    }
                    
                    HStack {
                        Text("선호 나이")
                        Spacer()
                        TextField("최소", text: $preferredAgeMin)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                        Text("-")
                        TextField("최대", text: $preferredAgeMax)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                        Text("세")
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("프로필 편집")
            .navigationBarItems(
                leading: Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("저장") {
                    saveProfile()
                }
                .disabled(isLoading)
            )
            .onAppear {
                loadProfile()
            }
        }
    }
    
    func loadProfile() {
        if let user = user {
            displayName = user.displayName
            bio = user.bio ?? ""
            age = String(user.age ?? 18)
            selectedGender = user.gender ?? "prefer_not_to_say"
            country = user.country ?? ""
            preferredGender = "" // TODO: Add preferred gender to User model
            preferredAgeMin = String(user.preferredAgeMin ?? 18)
            preferredAgeMax = String(user.preferredAgeMax ?? 100)
            isProfilePublic = user.isProfilePublic ?? true
            allowRandomCalls = user.allowRandomCalls ?? true
        }
    }
    
    func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // TODO: Implement user update API call
                // let updatedUser = try await UserService.shared.updateProfile(...)
                
                // For now, just create a new user object with updated values
                var updatedUser = user ?? User(
                    id: UUID().uuidString,
                    email: "",
                    username: "",
                    displayName: displayName,
                    age: Int(age),
                    gender: selectedGender,
                    country: country,
                    bio: bio.isEmpty ? nil : bio,
                    interests: nil,
                    profileImageUrl: nil,
                    photos: nil,
                    location: nil,
                    status: nil,
                    accountType: nil,
                    role: nil,
                    gems: nil,
                    lastSeen: nil,
                    isVerified: nil,
                    isActive: nil,
                    createdAt: Date(),
                    updatedAt: nil,
                    preferredGender: preferredGender.isEmpty ? nil : preferredGender,
                    preferredAgeMin: Int(preferredAgeMin),
                    preferredAgeMax: Int(preferredAgeMax),
                    isProfilePublic: isProfilePublic,
                    allowRandomCalls: allowRandomCalls
                )
                
                await MainActor.run {
                    onSave(updatedUser)
                    presentationMode.wrappedValue.dismiss()
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

// 내 아이템 뷰
struct MyItemsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.ownedItems.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "bag.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("보유한 아이템이 없습니다")
                            .foregroundColor(.gray)
                        
                        NavigationLink(destination: GemStoreView(viewModel: viewModel)) {
                            Text("상점 가기")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .cornerRadius(20)
                        }
                        
                        Spacer()
                    }
                    .frame(minHeight: 300)
                } else {
                    ForEach(StoreCategory.allCases, id: \.self) { category in
                        let items = viewModel.ownedItems.filter { $0.category == category }
                        if !items.isEmpty {
                            VStack(alignment: .leading) {
                                Text(categoryTitle(for: category))
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(items) { item in
                                            ItemCard(item: item)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("내 아이템")
    }
    
    func categoryTitle(for category: StoreCategory) -> String {
        switch category {
        case .filter: return "필터"
        case .gift: return "선물"
        case .vip: return "VIP"
        case .gems: return "보석"
        }
    }
}

// 구매 내역 뷰
struct PurchaseHistoryView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        Text("구매 내역")
            .navigationTitle("구매 내역")
    }
}

// 포인트 내역 뷰
struct PointHistoryView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        Text("포인트 내역")
            .navigationTitle("포인트 내역")
    }
}

// 설정 뷰
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var notificationSettings = NotificationSettings()
    @State private var privacySettings = PrivacySettings()
    @State private var showPasswordChange = false
    @State private var show2FASettings = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("알림 설정")) {
                    Toggle("푸시 알림", isOn: $notificationSettings.pushEnabled)
                    Toggle("친구 요청 알림", isOn: $notificationSettings.friendRequestsEnabled)
                    Toggle("메시지 알림", isOn: $notificationSettings.messagesEnabled)
                    Toggle("통화 알림", isOn: $notificationSettings.callsEnabled)
                }
                
                Section(header: Text("프라이버시")) {
                    Toggle("온라인 상태 표시", isOn: $privacySettings.showOnlineStatus)
                    Toggle("읽음 확인 표시", isOn: $privacySettings.showReadReceipts)
                    Toggle("위치 공유", isOn: $privacySettings.shareLocation)
                }
                
                Section(header: Text("보안")) {
                    Button(action: {
                        showPasswordChange = true
                    }) {
                        HStack {
                            Text("비밀번호 변경")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        show2FASettings = true
                    }) {
                        HStack {
                            Text("2단계 인증")
                            Spacer()
                            Text(privacySettings.twoFactorEnabled ? "사용 중" : "사용 안 함")
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("기타")) {
                    Button(action: {
                        // Clear cache
                    }) {
                        HStack {
                            Text("캐시 삭제")
                            Spacer()
                            Text("125 MB")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarItems(trailing: Button("완료") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showPasswordChange) {
                PasswordChangeView()
            }
            .sheet(isPresented: $show2FASettings) {
                TwoFactorSettingsView()
            }
        }
    }
}

// 아이템 카드
struct ItemCard: View {
    let item: StoreItem
    
    var body: some View {
        VStack {
            Image(systemName: item.iconName)
                .font(.system(size: 40))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(12)
            
            Text(item.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 100)
    }
}

// MARK: - Additional Views

// 알림 설정 뷰
struct NotificationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var settings = NotificationSettings()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("알림 유형")) {
                    Toggle("친구 요청", isOn: $settings.friendRequestsEnabled)
                    Toggle("메시지", isOn: $settings.messagesEnabled)
                    Toggle("통화", isOn: $settings.callsEnabled)
                    Toggle("선물", isOn: $settings.giftsEnabled)
                }
                
                Section(header: Text("알림 시간")) {
                    Toggle("방해 금지 모드", isOn: $settings.doNotDisturb)
                    if settings.doNotDisturb {
                        DatePicker("시작 시간", selection: $settings.quietHoursStart, displayedComponents: .hourAndMinute)
                        DatePicker("종료 시간", selection: $settings.quietHoursEnd, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("알림 설정")
            .navigationBarItems(trailing: Button("완료") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 프라이버시 설정 뷰
struct PrivacySettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var settings = PrivacySettings()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("프로필 공개")) {
                    Toggle("프로필 공개", isOn: $settings.profilePublic)
                    Toggle("온라인 상태 표시", isOn: $settings.showOnlineStatus)
                    Toggle("마지막 접속 시간 표시", isOn: $settings.showLastSeen)
                }
                
                Section(header: Text("차단 관리")) {
                    NavigationLink(destination: BlockedUsersView()) {
                        HStack {
                            Text("차단한 사용자")
                            Spacer()
                            Text("0명")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("프라이버시")
            .navigationBarItems(trailing: Button("완료") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 도움말 센터 뷰
struct HelpCenterView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let helpTopics = [
        ("시작하기", "앱 사용법과 기본 기능"),
        ("계정 및 프로필", "계정 관리와 프로필 설정"),
        ("친구 및 메시지", "친구 추가와 채팅 기능"),
        ("화상 통화", "화상 통화 사용 방법"),
        ("결제 및 환불", "보석 구매와 환불 정책"),
        ("문제 해결", "일반적인 문제와 해결 방법")
    ]
    
    var body: some View {
        NavigationView {
            List(helpTopics, id: \.0) { topic in
                NavigationLink(destination: HelpDetailView(title: topic.0)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.0)
                            .font(.headline)
                        Text(topic.1)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("도움말")
            .navigationBarItems(trailing: Button("완료") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 문의하기 뷰
struct ContactUsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var subject = ""
    @State private var message = ""
    @State private var email = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("문의 정보")) {
                    TextField("이메일", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("제목", text: $subject)
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                }
                
                Section {
                    Button("문의 보내기") {
                        // Send inquiry
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(subject.isEmpty || message.isEmpty || email.isEmpty)
                }
            }
            .navigationTitle("문의하기")
            .navigationBarItems(
                leading: Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("보내기") {
                    // Send inquiry
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(subject.isEmpty || message.isEmpty || email.isEmpty)
            )
        }
    }
}

// 이용약관 뷰
struct TermsOfServiceView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("이용약관")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("최종 수정일: 2024년 1월 1일")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Terms content here
                    Text("""
                    1. 서비스 이용
                    - 본 서비스는 만 18세 이상만 이용할 수 있습니다.
                    - 이용자는 관련 법령을 준수해야 합니다.
                    
                    2. 개인정보 보호
                    - 개인정보는 안전하게 보호됩니다.
                    - 개인정보 처리방침에 따라 처리됩니다.
                    
                    3. 콘텐츠 정책
                    - 불법적이거나 유해한 콘텐츠는 금지됩니다.
                    - 다른 사용자의 권리를 침해하지 마세요.
                    
                    4. 서비스 이용 제한
                    - 약관 위반 시 서비스 이용이 제한될 수 있습니다.
                    - 계정이 정지되거나 삭제될 수 있습니다.
                    """)
                }
                .padding()
            }
            .navigationTitle("이용약관")
            .navigationBarItems(trailing: Button("닫기") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 비밀번호 변경 뷰
struct PasswordChangeView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("현재 비밀번호")) {
                    SecureField("현재 비밀번호", text: $currentPassword)
                }
                
                Section(header: Text("새 비밀번호")) {
                    SecureField("새 비밀번호", text: $newPassword)
                    SecureField("비밀번호 확인", text: $confirmPassword)
                }
                
                Section {
                    Text("비밀번호는 8자 이상이어야 합니다.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("비밀번호 변경")
            .navigationBarItems(
                leading: Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("저장") {
                    changePassword()
                }
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
            )
            .alert(isPresented: $showAlert) {
                Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인")))
            }
        }
    }
    
    func changePassword() {
        guard newPassword == confirmPassword else {
            alertMessage = "새 비밀번호가 일치하지 않습니다."
            showAlert = true
            return
        }
        
        guard newPassword.count >= 8 else {
            alertMessage = "비밀번호는 8자 이상이어야 합니다."
            showAlert = true
            return
        }
        
        // TODO: Implement password change API call
        alertMessage = "비밀번호가 변경되었습니다."
        showAlert = true
        presentationMode.wrappedValue.dismiss()
    }
}

// 2단계 인증 설정 뷰
struct TwoFactorSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isEnabled = false
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var showVerification = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("2단계 인증 사용", isOn: $isEnabled)
                }
                
                if isEnabled {
                    Section(header: Text("전화번호")) {
                        TextField("전화번호", text: $phoneNumber)
                            .keyboardType(.phonePad)
                        
                        Button("인증번호 받기") {
                            // Send verification code
                            showVerification = true
                        }
                        .disabled(phoneNumber.isEmpty)
                    }
                    
                    if showVerification {
                        Section(header: Text("인증번호")) {
                            TextField("인증번호", text: $verificationCode)
                                .keyboardType(.numberPad)
                            
                            Button("확인") {
                                // Verify code
                                presentationMode.wrappedValue.dismiss()
                            }
                            .disabled(verificationCode.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("2단계 인증")
            .navigationBarItems(trailing: Button("완료") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 차단된 사용자 뷰
struct BlockedUsersView: View {
    @State private var blockedUsers: [String] = []
    
    var body: some View {
        List {
            if blockedUsers.isEmpty {
                Text("차단한 사용자가 없습니다.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(blockedUsers, id: \.self) { user in
                    HStack {
                        Text(user)
                        Spacer()
                        Button("차단 해제") {
                            // Unblock user
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("차단 관리")
    }
}

// 도움말 상세 뷰
struct HelpDetailView: View {
    let title: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.largeTitle)
                    .bold()
                
                // Help content based on title
                Text(getHelpContent(for: title))
                    .font(.body)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func getHelpContent(for title: String) -> String {
        switch title {
        case "시작하기":
            return """
            앱을 처음 사용하시는 경우:
            
            1. 회원가입 또는 로그인
            2. 프로필 설정
            3. 친구 추가
            4. 채팅 시작
            5. 화상 통화 즐기기
            """
        case "계정 및 프로필":
            return """
            계정 관리:
            
            - 프로필 사진 변경
            - 개인정보 수정
            - 비밀번호 변경
            - 계정 삭제
            """
        default:
            return "상세 도움말 내용"
        }
    }
}

// MARK: - Models

struct NotificationSettings {
    var pushEnabled = true
    var friendRequestsEnabled = true
    var messagesEnabled = true
    var callsEnabled = true
    var giftsEnabled = true
    var doNotDisturb = false
    var quietHoursStart = Date()
    var quietHoursEnd = Date()
}

struct PrivacySettings {
    var profilePublic = true
    var showOnlineStatus = true
    var showLastSeen = true
    var showReadReceipts = true
    var shareLocation = false
    var twoFactorEnabled = false
}

