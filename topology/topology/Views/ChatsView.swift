import SwiftUI

struct ChatsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 탭 선택 (전체/온라인)
                HStack {
                    Button(action: {
                        selectedTab = 0
                    }) {
                        Text("전체")
                            .font(.headline)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(selectedTab == 0 ? Color.green : Color.clear)
                            .foregroundColor(selectedTab == 0 ? .white : .gray)
                            .cornerRadius(20)
                    }
                    
                    Button(action: {
                        selectedTab = 1
                    }) {
                        HStack {
                            Text("온라인")
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(selectedTab == 1 ? Color.green : Color.clear)
                        .foregroundColor(selectedTab == 1 ? .white : .gray)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 채팅 목록
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredFriends) { friend in
                            NavigationLink(destination: ChatView(friend: friend)) {
                                ChatRow(friend: friend, viewModel: viewModel)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("채팅")
            .searchable(text: $viewModel.searchText, prompt: "이름으로 검색")
        }
    }
    
    var filteredFriends: [Friend] {
        let friends = selectedTab == 0 ? viewModel.friends : viewModel.friends.filter { $0.isOnline }
        
        if viewModel.searchText.isEmpty {
            return friends.filter { !$0.isHidden && !$0.isBlocked }
        } else {
            return friends.filter {
                $0.name.lowercased().contains(viewModel.searchText.lowercased()) &&
                !$0.isHidden && !$0.isBlocked
            }
        }
    }
}

// 채팅 행 뷰
struct ChatRow: View {
    let friend: Friend
    @ObservedObject var viewModel: FriendsViewModel
    
    var lastMessage: ChatMessage? {
        viewModel.chatMessages[friend.id.uuidString]?.last
    }
    
    var unreadCount: Int {
        // 실제로는 읽지 않은 메시지 수를 추적해야 함
        return Int.random(in: 0...5)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 56, height: 56)
                
                Text("👤")
                    .font(.title2)
            }
            .overlay(
                Circle()
                    .fill(friend.isOnline ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .offset(x: 20, y: -20)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend.name)
                        .font(.headline)
                    
                    if friend.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                    }
                    
                    Spacer()
                    
                    // 시간 표시
                    if let message = lastMessage {
                        Text(formatTime(message.time))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    if let message = lastMessage {
                        Text(message.content)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else {
                        Text("대화를 시작해보세요")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    
                    Spacer()
                    
                    // 읽지 않은 메시지 수
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "a h:mm"
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else {
            formatter.dateFormat = "M/d"
        }
        
        return formatter.string(from: date)
    }
}

// 채팅 화면
struct ChatView: View {
    let friend: Friend
    @StateObject private var viewModel = FriendsViewModel()
    @State private var messageText = ""
    @State private var showActionSheet = false
    
    var messages: [ChatMessage] {
        viewModel.chatMessages[friend.id.uuidString] ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 메시지 목록
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // 입력 바
            ChatInputBar(messageText: $messageText) {
                sendMessage()
            }
        }
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button(action: {
            showActionSheet = true
        }) {
            Image(systemName: "ellipsis")
        })
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("채팅 메뉴"),
                buttons: [
                    .default(Text("영상통화 시작")) {
                        // 영상통화 시작
                    },
                    .default(Text("선물 보내기")) {
                        // 선물 보내기
                    },
                    .destructive(Text("채팅방 나가기")) {
                        viewModel.deleteChat(with: friend)
                    },
                    .destructive(Text("친구 차단")) {
                        viewModel.blockFriend(friend)
                    },
                    .cancel()
                ]
            )
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        viewModel.sendMessage(to: friend, message: messageText)
        messageText = ""
    }
}

// 메시지 버블
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
            }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isFromMe ? Color.green : Color.gray.opacity(0.3))
                    .foregroundColor(message.isFromMe ? .white : .white)
                    .cornerRadius(16)
                
                Text(formatTime(message.time))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !message.isFromMe {
                Spacer()
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
}

// 채팅 입력 바
struct ChatInputBar: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 추가 기능 버튼
            Button(action: {
                // 사진, 영상 등 추가
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
            
            // 텍스트 입력
            TextField("메시지 입력...", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // 전송 버튼
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(messageText.isEmpty ? .gray : .green)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }
}

// 선물 아이템 모델
struct GiftItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let price: Int
    let iconName: String
}

// 선물 보내기 뷰
struct SendGiftView: View {
    let friend: Friend
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let gifts = [
        GiftItem(name: "하트", description: "사랑을 표현하는 하트", price: 10, iconName: "heart.fill"),
        GiftItem(name: "꽃다발", description: "아름다운 꽃다발", price: 30, iconName: "camera.macro"),
        GiftItem(name: "커피", description: "따뜻한 커피 한 잔", price: 20, iconName: "cup.and.saucer.fill"),
        GiftItem(name: "케이크", description: "달콤한 케이크", price: 50, iconName: "birthday.cake.fill"),
        GiftItem(name: "반지", description: "빛나는 반지", price: 100, iconName: "diamond"),
        GiftItem(name: "시계", description: "고급스러운 시계", price: 200, iconName: "clock.fill")
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // 받는 사람 정보
                HStack {
                    Text("받는 사람:")
                        .foregroundColor(.gray)
                    Text(friend.name)
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.2))
                
                // 내 보석
                HStack {
                    Text("내 보석:")
                        .foregroundColor(.gray)
                    Image(systemName: "diamond.fill")
                        .foregroundColor(.yellow)
                    Text("\(viewModel.myGems)")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.2))
                
                // 선물 목록
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(gifts) { gift in
                            GiftCard(gift: gift, viewModel: viewModel, friend: friend)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("선물 보내기")
            .navigationBarItems(trailing: Button("취소") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 선물 카드
struct GiftCard: View {
    let gift: GiftItem
    @ObservedObject var viewModel: FriendsViewModel
    let friend: Friend
    @State private var showAlert = false
    @State private var purchaseResult: (success: Bool, message: String) = (false, "")
    
    var body: some View {
        VStack {
            Image(systemName: gift.iconName)
                .font(.system(size: 40))
                .foregroundColor(.white)
                .frame(height: 60)
            
            Text(gift.name)
                .font(.headline)
            
            HStack {
                Image(systemName: "diamond.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                Text("\(gift.price)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Button(action: {
                sendGift()
            }) {
                Text("보내기")
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(viewModel.myGems >= gift.price ? Color.green : Color.gray)
                    .cornerRadius(15)
            }
            .disabled(viewModel.myGems < gift.price)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(purchaseResult.success ? "선물 전송 완료" : "선물 전송 실패"),
                message: Text(purchaseResult.message),
                dismissButton: .default(Text("확인"))
            )
        }
    }
    
    func sendGift() {
        // Create a temporary StoreItem from GiftItem
        let storeItem = StoreItem(
            itemId: UUID().uuidString,
            name: gift.name,
            description: gift.description,
            price: Double(gift.price),
            category: .gift,
            stock: 1,
            purchaseCount: 0,
            isFeatured: false,
            isLimited: false,
            isActive: true,
            createdAt: Date(),
            updatedAt: nil
        )
        
        if viewModel.purchaseItem(storeItem) {
            purchaseResult = (true, "\(friend.name)님에게 \(gift.name)을(를) 보냈습니다.")
            
            // 시스템 메시지로 선물 전송 기록
            let giftMessage = ChatMessage(
                sender: "시스템",
                content: "🎁 \(gift.name)을(를) 보냈습니다.",
                time: Date(),
                isFromMe: true
            )
            viewModel.sendMessage(to: friend, message: giftMessage.content)
        } else {
            purchaseResult = (false, "보석이 부족합니다.")
        }
        showAlert = true
    }
}