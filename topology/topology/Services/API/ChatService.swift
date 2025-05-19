import Foundation

class ChatService {
    static let shared = ChatService()
    private let apiClient = APIClient.shared
    
    private init() {}
    
    // MARK: - Get Chats
    
    func getChats(limit: Int = 20, offset: Int = 0) async throws -> [ChatOut] {
        let endpoint = "/chats?limit=\(limit)&offset=\(offset)"
        return try await apiClient.request(endpoint, authenticated: true)
    }
    
    // MARK: - Get Chat Messages
    
    func getChatMessages(
        with userId: String,
        limit: Int = 50,
        before: String? = nil
    ) async throws -> [ChatMessageOut] {
        var endpoint = "/chats/\(userId)/messages?limit=\(limit)"
        if let before = before {
            endpoint += "&before=\(before)"
        }
        
        return try await apiClient.request(endpoint, authenticated: true)
    }
    
    // MARK: - Send Message
    
    func sendMessage(to userId: String, content: String) async throws -> ChatMessageOut {
        let body = ChatMessageRequest(content: content)
        let data = try JSONEncoder().encode(body)
        
        return try await apiClient.request(
            "/chats/\(userId)/messages",
            method: "POST",
            body: data,
            authenticated: true
        )
    }
    
    // MARK: - Mark Message as Read
    
    func markMessageAsRead(messageId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            "/chats/messages/\(messageId)/read",
            method: "PUT",
            authenticated: true
        )
    }
    
    // MARK: - Delete Message
    
    func deleteMessage(messageId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            "/chats/messages/\(messageId)",
            method: "DELETE",
            authenticated: true
        )
    }
    
    // MARK: - Get Unread Count
    
    func getUnreadCount() async throws -> Int {
        let response: UnreadCountResponse = try await apiClient.request(
            "/chats/unread/count",
            authenticated: true
        )
        return response.unreadCount
    }
    
    // MARK: - Send Typing Indicator
    
    func sendTypingIndicator(to userId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            "/chats/\(userId)/typing",
            method: "POST",
            authenticated: true
        )
    }
}

// MARK: - Chat Models

struct ChatMessageRequest: Codable {
    let content: String
}

struct ChatOut: Codable, Identifiable {
    let conversationId: String
    let user: ChatUser
    let lastMessage: LastMessage
    let unreadCount: Int
    let isOnline: Bool
    
    var id: String { conversationId }
}

struct ChatUser: Codable {
    let userId: String
    let username: String
    let displayName: String
    let profilePhoto: String?
    
    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case profilePhoto = "profile_photo"
    }
}

struct LastMessage: Codable {
    let messageId: String
    let content: String
    let isRead: Bool
    let createdAt: Date
    let isSent: Bool
}

struct ChatMessageOut: Codable, Identifiable {
    let messageId: String
    let senderId: String
    let receiverId: String
    let content: String
    let isRead: Bool
    let createdAt: Date
    let isSent: Bool
    
    var id: String { messageId }
}

struct UnreadCountResponse: Codable {
    let unreadCount: Int
}