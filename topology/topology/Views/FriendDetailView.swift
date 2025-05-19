import SwiftUI

struct FriendDetailView: View {
    let friend: Friend
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showConfirmation = false
    @State private var actionType: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 프로필 헤더
                ProfileHeader(friend: friend)
                
                // 액션 버튼들
                ActionButtons(friend: friend, viewModel: viewModel)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal)
                
                // 친구 정보
                FriendInfo(friend: friend)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal)
                
                // 친구 관리 옵션
                ManagementOptions(friend: friend, actionType: $actionType, showConfirmation: $showConfirmation)
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("친구 정보")
        .alert(isPresented: $showConfirmation) {
            createAlert(for: actionType)
        }
    }
    
    func createAlert(for type: String) -> Alert {
        switch type {
        case "hide":
            return Alert(
                title: Text("친구 숨기기"),
                message: Text("\(friend.name)님을 정말 숨기시겠습니까? 숨긴 친구는 '숨김친구 관리'에서 다시 볼 수 있습니다."),
                primaryButton: .destructive(Text("숨기기")) {
                    viewModel.hideFriend(friend)
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("취소"))
            )
        case "block":
            return Alert(
                title: Text("친구 차단하기"),
                message: Text("\(friend.name)님을 정말 차단하시겠습니까? 차단된 친구는 더 이상 연락할 수 없습니다."),
                primaryButton: .destructive(Text("차단하기")) {
                    viewModel.blockFriend(friend)
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("취소"))
            )
        case "delete":
            return Alert(
                title: Text("친구 삭제"),
                message: Text("\(friend.name)님을 친구 목록에서 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다."),
                primaryButton: .destructive(Text("삭제")) {
                    viewModel.friends.removeAll { $0.id == friend.id }
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("취소"))
            )
        default:
            return Alert(title: Text("알 수 없는 작업"))
        }
    }
}

// 프로필 헤더
struct ProfileHeader: View {
    let friend: Friend
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                
                Text("👤")
                    .font(.system(size: 60))
            }
            .overlay(
                Circle()
                    .fill(friend.isOnline ? Color.green : Color.gray)
                    .frame(width: 24, height: 24)
                    .offset(x: 48, y: -48)
            )
            
            VStack(spacing: 4) {
                HStack {
                    Text(friend.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if friend.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 18))
                    }
                }
                
                Text("\(friend.age)세 • \(friend.country)")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text(friend.isOnline ? "온라인" : "마지막 접속: \(friend.lastSeen)")
                    .font(.subheadline)
                    .foregroundColor(friend.isOnline ? .green : .gray)
                    .padding(.top, 4)
            }
        }
        .padding()
    }
}

// 액션 버튼들
struct ActionButtons: View {
    let friend: Friend
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        HStack(spacing: 24) {
            NavigationLink(destination: ChatView(friend: friend)) {
                VStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text("메시지")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            NavigationLink(destination: VideoCallView(friend: friend)) {
                VStack {
                    Image(systemName: "video.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.green)
                        .clipShape(Circle())
                    
                    Text("영상통화")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Button(action: {
                viewModel.toggleFavorite(for: friend)
            }) {
                VStack {
                    Image(systemName: friend.isFavorite ? "star.slash.fill" : "star.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.yellow)
                        .clipShape(Circle())
                    
                    Text(friend.isFavorite ? "즐겨찾기 해제" : "즐겨찾기")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            NavigationLink(destination: SendGiftView(friend: friend, viewModel: viewModel)) {
                VStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.pink)
                        .clipShape(Circle())
                    
                    Text("선물")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// 친구 정보
struct FriendInfo: View {
    let friend: Friend
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoRow(icon: "person.fill", title: "이름", value: friend.name)
            InfoRow(icon: "number", title: "나이", value: "\(friend.age)세")
            InfoRow(icon: "location.fill", title: "위치", value: friend.country)
            InfoRow(icon: "clock.fill", title: "마지막 접속", value: friend.isOnline ? "현재 온라인" : friend.lastSeen)
        }
        .padding()
    }
}

// 정보 행
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// 친구 관리 옵션
struct ManagementOptions: View {
    let friend: Friend
    @Binding var actionType: String
    @Binding var showConfirmation: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 친구 숨기기
            if !friend.isHidden {
                ManagementButton(
                    icon: "eye.slash",
                    title: "친구 숨기기",
                    color: .white,
                    action: {
                        actionType = "hide"
                        showConfirmation = true
                    }
                )
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal)
            
            // 친구 차단하기
            if !friend.isBlocked {
                ManagementButton(
                    icon: "hand.raised",
                    title: "친구 차단하기",
                    color: .orange,
                    action: {
                        actionType = "block"
                        showConfirmation = true
                    }
                )
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal)
            
            // 친구 삭제
            ManagementButton(
                icon: "trash",
                title: "친구 삭제",
                color: .red,
                action: {
                    actionType = "delete"
                    showConfirmation = true
                }
            )
        }
        .padding(.top)
    }
}

// 관리 버튼
struct ManagementButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding()
            .background(Color.black.opacity(0.2))
        }
    }
}