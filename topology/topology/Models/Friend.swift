import Foundation

struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let profileImage: String
    let age: Int
    let country: String
    let isOnline: Bool
    let lastSeen: String
    var isHidden: Bool = false
    var isBlocked: Bool = false
    var isFavorite: Bool = false
}

// 채팅 메시지 모델
struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let content: String
    let time: Date
    let isFromMe: Bool
}

// 통화 기록 모델
struct CallRecord: Identifiable {
    let id = UUID()
    let friend: Friend
    let startTime: Date
    let duration: TimeInterval
    let isVideoCall: Bool
    let isIncoming: Bool
}

// 필터 모델
struct Filter: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let isPremium: Bool
    let requiredGems: Int
}

// StoreItem is now defined in StoreService.swift to avoid duplication

enum StoreCategory: String, CaseIterable, Codable {
    case filter = "filter"
    case gift = "gift"
    case vip = "vip"
    case gems = "gems"
}

// 프로필 설정 모델
struct ProfileSettings {
    var username: String
    var bio: String
    var age: Int
    var gender: Gender
    var country: String
    var profileImageName: String
    var isProfilePublic: Bool
    var allowRandomCalls: Bool
    var preferredGender: Gender
    var preferredAgeRange: ClosedRange<Int>
}

enum Gender: String, CaseIterable {
    case male = "남성"
    case female = "여성"
    case all = "모두"
}