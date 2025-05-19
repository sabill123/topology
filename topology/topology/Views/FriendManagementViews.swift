import SwiftUI

// 친구 추가/초대 뷰
struct InviteFriendView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: FriendsViewModel
    @State private var phoneNumber = ""
    @State private var name = ""
    @State private var age = ""
    @State private var invitationSent = false
    @State private var selectedMethod = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 보상 안내
                    RewardBanner()
                    
                    // 초대 방법 선택
                    Picker("초대 방법", selection: $selectedMethod) {
                        Text("전화번호").tag(0)
                        Text("연락처").tag(1)
                        Text("SNS 공유").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // 초대 내용
                    if selectedMethod == 0 {
                        PhoneInviteView(
                            phoneNumber: $phoneNumber,
                            invitationSent: $invitationSent,
                            viewModel: viewModel
                        )
                    } else if selectedMethod == 1 {
                        ContactInviteView(viewModel: viewModel)
                    } else {
                        SNSShareView()
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("친구 초대")
            .navigationBarItems(trailing: Button("취소") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 보상 배너
struct RewardBanner: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("친구를 초대하고 보상 받으세요!")
                .font(.headline)
            
            HStack(spacing: 20) {
                RewardItem(icon: "💎", title: "10 보석", description: "친구 가입 시")
                RewardItem(icon: "🎁", title: "선물 상자", description: "첫 통화 시")
                RewardItem(icon: "🎭", title: "VIP 필터", description: "5명 초대 시")
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .padding()
    }
}

// 보상 아이템
struct RewardItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title)
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
            Text(description)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// 전화번호 초대
struct PhoneInviteView: View {
    @Binding var phoneNumber: String
    @Binding var invitationSent: Bool
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("전화번호 입력", text: $phoneNumber)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.phonePad)
                .padding()
            
            Button(action: {
                if viewModel.inviteFriend(phoneNumber: phoneNumber) {
                    invitationSent = true
                }
            }) {
                Text("초대 문자 보내기")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(phoneNumber.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(12)
            }
            .disabled(phoneNumber.isEmpty)
            .padding(.horizontal)
            
            if invitationSent {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("초대가 전송되었습니다!")
                        .foregroundColor(.green)
                }
                .padding()
            }
        }
    }
}

// 연락처 초대
struct ContactInviteView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        VStack {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding()
            
            Text("연락처에서 친구를 선택하세요")
                .font(.headline)
            
            Button(action: {
                // 연락처 권한 요청 및 접근
            }) {
                Text("연락처 열기")
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(25)
            }
            .padding()
        }
    }
}

// SNS 공유
struct SNSShareView: View {
    let shareOptions = [
        ("message.fill", "문자"),
        ("paperplane.fill", "카카오톡"),
        ("f.circle.fill", "페이스북"),
        ("camera.macro", "인스타그램")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SNS로 초대 링크 공유하기")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(shareOptions, id: \.0) { icon, title in
                    ShareButton(icon: icon, title: title)
                }
            }
            .padding()
        }
    }
}

// 공유 버튼
struct ShareButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        Button(action: {
            // 공유 액션
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.green)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}

// 숨김 친구 관리
struct HiddenFriendsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        if viewModel.hiddenFriends.isEmpty {
            EmptyStateView(
                icon: "eye.slash",
                title: "숨긴 친구가 없습니다",
                message: "친구 프로필에서 친구를 숨길 수 있습니다"
            )
        } else {
            List {
                ForEach(viewModel.hiddenFriends) { friend in
                    HiddenFriendRow(friend: friend, viewModel: viewModel)
                }
            }
            .navigationTitle("숨김친구 관리")
        }
    }
}

// 숨김 친구 행
struct HiddenFriendRow: View {
    let friend: Friend
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        HStack {
            // 프로필 이미지
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text("👤")
                        .font(.title3)
                )
            
            VStack(alignment: .leading) {
                Text(friend.name)
                    .font(.headline)
                Text("\(friend.age)세 • \(friend.country)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.unhideFriend(friend)
            }) {
                Text("숨김 해제")
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.green, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 8)
    }
}

// 차단 친구 관리
struct BlockedFriendsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        if viewModel.blockedFriends.isEmpty {
            EmptyStateView(
                icon: "hand.raised",
                title: "차단한 친구가 없습니다",
                message: "친구 프로필에서 친구를 차단할 수 있습니다"
            )
        } else {
            List {
                ForEach(viewModel.blockedFriends) { friend in
                    BlockedFriendRow(friend: friend, viewModel: viewModel)
                }
            }
            .navigationTitle("차단친구 관리")
        }
    }
}

// 차단 친구 행
struct BlockedFriendRow: View {
    let friend: Friend
    @ObservedObject var viewModel: FriendsViewModel
    @State private var showUnblockAlert = false
    
    var body: some View {
        HStack {
            // 프로필 이미지
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text("👤")
                        .font(.title3)
                )
            
            VStack(alignment: .leading) {
                Text(friend.name)
                    .font(.headline)
                Text("\(friend.age)세 • \(friend.country)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                showUnblockAlert = true
            }) {
                Text("차단 해제")
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.red, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 8)
        .alert(isPresented: $showUnblockAlert) {
            Alert(
                title: Text("차단 해제"),
                message: Text("\(friend.name)님의 차단을 해제하시겠습니까?"),
                primaryButton: .default(Text("해제")) {
                    viewModel.unblockFriend(friend)
                },
                secondaryButton: .cancel(Text("취소"))
            )
        }
    }
}

// 빈 상태 뷰
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}