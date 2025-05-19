import Foundation
import SwiftUI
import Combine

class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var onlineFriends: [Friend] = []
    @Published var pendingRequests: [Friend] = []
    @Published var myGems: Int = 1595
    @Published var selectedTab: Int = 0
    @Published var searchText = ""
    @Published var currentFilter: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var profileSettings = ProfileSettings(
        username: "나",
        bio: "안녕하세요!",
        age: 25,
        gender: .all,
        country: "한국",
        profileImageName: "person.fill",
        isProfilePublic: true,
        allowRandomCalls: true,
        preferredGender: .all,
        preferredAgeRange: 18...50
    )
    
    @Published var chatMessages: [String: [ChatMessage]] = [:]
    @Published var callRecords: [CallRecord] = []
    @Published var availableFilters: [Filter] = []
    @Published var storeItems: [StoreItem] = []
    @Published var ownedItems: [StoreItem] = []
    
    private let friendsService = FriendsService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupWebSocketListeners()
        Task {
            await loadFriendsFromAPI()
        }
    }
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friends.filter { !$0.isHidden && !$0.isBlocked }
        } else {
            return friends.filter { $0.name.lowercased().contains(searchText.lowercased()) && !$0.isHidden && !$0.isBlocked }
        }
    }
    
    var favoriteFriends: [Friend] {
        return friends.filter { $0.isFavorite && !$0.isHidden && !$0.isBlocked }
    }
    
    var hiddenFriends: [Friend] {
        return friends.filter { $0.isHidden }
    }
    
    var blockedFriends: [Friend] {
        return friends.filter { $0.isBlocked }
    }
    
    // MARK: - API Methods
    
    @MainActor
    func loadFriendsFromAPI() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load accepted friends
            let acceptedFriends = try await friendsService.getFriends(status: .accepted)
            
            // Load pending requests
            let pendingRequests = try await friendsService.getReceivedRequests()
            
            // Convert to local Friend model
            self.friends = acceptedFriends.map { friendOut in
                Friend(
                    name: friendOut.displayName,
                    profileImage: friendOut.profilePhoto ?? "person.fill",
                    age: 0, // Age not provided in FriendOut
                    country: "", // Country not provided in FriendOut
                    isOnline: friendOut.isOnline,
                    lastSeen: friendOut.isOnline ? "방금 전" : "오프라인",
                    isHidden: false,
                    isBlocked: false,
                    isFavorite: false
                )
            }
            
            self.pendingRequests = pendingRequests.map { friendOut in
                Friend(
                    name: friendOut.displayName,
                    profileImage: friendOut.profilePhoto ?? "person.fill",
                    age: 0,
                    country: "",
                    isOnline: friendOut.isOnline,
                    lastSeen: friendOut.isOnline ? "방금 전" : "오프라인"
                )
            }
            
            // Filter online friends
            self.onlineFriends = self.friends.filter { $0.isOnline }
            
            // Load other data
            loadChatMessages()
            loadCallRecords()
            loadFilters()
            loadStoreItems()
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - WebSocket Setup
    
    private func setupWebSocketListeners() {
        WebSocketService.shared.receivedMessage
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message.type {
        case "friend_request":
            // Handle new friend request
            Task {
                await loadFriendsFromAPI()
            }
            
        case "friend_request_accepted":
            // Handle accepted friend request
            Task {
                await loadFriendsFromAPI()
            }
            
        case "user_typing":
            // Handle typing indicator
            if let userId = message.data["user_id"] as? String {
                // Update UI to show typing indicator
            }
            
        default:
            break
        }
    }
    
    func loadFriends() {
        // For compatibility, keep this method but use API
        Task {
            await loadFriendsFromAPI()
        }
        
        // 샘플 채팅 메시지 로드
        for friend in friends {
            chatMessages[friend.id.uuidString] = [
                ChatMessage(sender: friend.name, content: "안녕하세요!", time: Date().addingTimeInterval(-3600), isFromMe: false),
                ChatMessage(sender: "나", content: "안녕하세요~", time: Date().addingTimeInterval(-3000), isFromMe: true),
                ChatMessage(sender: friend.name, content: "오늘 날씨가 좋네요", time: Date().addingTimeInterval(-2400), isFromMe: false),
                ChatMessage(sender: "나", content: "네 정말 좋아요!", time: Date().addingTimeInterval(-1800), isFromMe: true)
            ]
        }
    }
    
    func loadFilters() {
        availableFilters = [
            Filter(name: "기본", iconName: "camera", isPremium: false, requiredGems: 0),
            Filter(name: "뷰티", iconName: "sparkles", isPremium: false, requiredGems: 0),
            Filter(name: "반짝이", iconName: "star.fill", isPremium: false, requiredGems: 0),
            Filter(name: "모노톤", iconName: "circle.lefthalf.filled", isPremium: false, requiredGems: 0),
            Filter(name: "빈티지", iconName: "photo", isPremium: false, requiredGems: 0),
            Filter(name: "모자이크", iconName: "square.grid.3x3", isPremium: true, requiredGems: 50),
            Filter(name: "선글라스", iconName: "eyeglasses", isPremium: true, requiredGems: 100),
            Filter(name: "고양이", iconName: "pawprint.fill", isPremium: true, requiredGems: 150),
            Filter(name: "강아지", iconName: "pawprint.fill", isPremium: true, requiredGems: 150),
            Filter(name: "토끼", iconName: "hare.fill", isPremium: true, requiredGems: 150)
        ]
    }
    
    func loadStoreItems() {
        // Store items will be loaded from API in real implementation
        Task {
            do {
                let items = try await StoreService.shared.getStoreItems()
                await MainActor.run {
                    self.storeItems = items
                }
            } catch {
                print("Failed to load store items: \(error)")
            }
        }
    }
    
    func loadChatMessages() {
        // Load chat messages from API or mock data
        for (friendId, _) in chatMessages {
            chatMessages[friendId] = []
        }
    }
    
    func loadCallRecords() {
        // 샘플 통화 기록
        if !friends.isEmpty {
            callRecords = [
                CallRecord(friend: friends[0], startTime: Date().addingTimeInterval(-86400), duration: 300, isVideoCall: true, isIncoming: false),
                CallRecord(friend: friends[1], startTime: Date().addingTimeInterval(-172800), duration: 600, isVideoCall: true, isIncoming: true),
                CallRecord(friend: friends[2], startTime: Date().addingTimeInterval(-259200), duration: 420, isVideoCall: false, isIncoming: false)
            ]
        }
    }
    
    func toggleFavorite(for friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].isFavorite.toggle()
        }
    }
    
    func hideFriend(_ friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].isHidden = true
        }
    }
    
    func unhideFriend(_ friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].isHidden = false
        }
    }
    
    func blockFriend(_ friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].isBlocked = true
        }
    }
    
    func unblockFriend(_ friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].isBlocked = false
        }
    }
    
    func addFriend(_ name: String, age: Int, country: String) {
        let newFriend = Friend(name: name, profileImage: "person.fill", age: age, country: country, isOnline: false, lastSeen: "방금 추가됨")
        friends.append(newFriend)
    }
    
    func inviteFriend(phoneNumber: String) -> Bool {
        myGems += 10
        return true
    }
    
    func purchaseItem(_ item: StoreItem) -> Bool {
        if myGems >= Int(item.price) {
            myGems -= Int(item.price)
            ownedItems.append(item)
            return true
        }
        return false
    }
    
    func sendMessage(to friend: Friend, message: String) {
        let newMessage = ChatMessage(sender: "나", content: message, time: Date(), isFromMe: true)
        if chatMessages[friend.id.uuidString] != nil {
            chatMessages[friend.id.uuidString]?.append(newMessage)
        } else {
            chatMessages[friend.id.uuidString] = [newMessage]
        }
    }
    
    func deleteChat(with friend: Friend) {
        chatMessages[friend.id.uuidString] = []
    }
}