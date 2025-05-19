import Foundation

class FriendsService {
    static let shared = FriendsService()
    private let apiClient = APIClient.shared
    
    private init() {}
    
    // MARK: - Get Friends
    
    func getFriends(status: FriendshipStatus? = nil) async throws -> [FriendOut] {
        var endpoint = "/friends"
        if let status = status {
            endpoint += "?status_filter=\(status.rawValue)"
        }
        
        return try await apiClient.request(endpoint, authenticated: true)
    }
    
    // MARK: - Send Friend Request
    
    func sendFriendRequest(to userId: String) async throws -> Friendship {
        let body = FriendRequest(friendId: userId)
        let data = try JSONEncoder().encode(body)
        
        return try await apiClient.request(
            "/friends/request",
            method: "POST",
            body: data,
            authenticated: true
        )
    }
    
    // MARK: - Accept Friend Request
    
    func acceptFriendRequest(friendshipId: String) async throws -> Friendship {
        return try await apiClient.request(
            "/friends/\(friendshipId)/accept",
            method: "PUT",
            authenticated: true
        )
    }
    
    // MARK: - Reject Friend Request
    
    func rejectFriendRequest(friendshipId: String) async throws -> Friendship {
        return try await apiClient.request(
            "/friends/\(friendshipId)/reject",
            method: "PUT",
            authenticated: true
        )
    }
    
    // MARK: - Remove Friend
    
    func removeFriend(friendshipId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            "/friends/\(friendshipId)",
            method: "DELETE",
            authenticated: true
        )
    }
    
    // MARK: - Get Pending Requests
    
    func getSentRequests() async throws -> [FriendOut] {
        return try await apiClient.request("/friends/pending/sent", authenticated: true)
    }
    
    func getReceivedRequests() async throws -> [FriendOut] {
        return try await apiClient.request("/friends/pending/received", authenticated: true)
    }
}

// MARK: - Friend Models

struct FriendRequest: Codable {
    let friendId: String
}

struct Friendship: Codable {
    let friendshipId: String
    let userId: String
    let friendId: String
    let status: FriendshipStatus
    let createdAt: Date
    let updatedAt: Date?
    let acceptedAt: Date?
    let rejectedAt: Date?
}

struct FriendOut: Codable, Identifiable {
    let friendshipId: String
    let userId: String
    let username: String
    let displayName: String
    let profilePhoto: String?
    let status: FriendshipStatus
    let isOnline: Bool
    let createdAt: Date
    let updatedAt: Date?
    
    var id: String { friendshipId }
    
    private enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case profilePhoto = "profile_photo"
        case status
        case isOnline = "is_online"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum FriendshipStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}