import Foundation

class StoreService {
    static let shared = StoreService()
    private let apiClient = APIClient.shared
    
    private init() {}
    
    // MARK: - Get Store Items
    
    func getStoreItems(
        category: StoreCategory? = nil,
        minPrice: Int? = nil,
        maxPrice: Int? = nil,
        search: String? = nil,
        sortBy: SortOption = .popularity,
        order: SortOrder = .desc,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [StoreItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "sort_by", value: sortBy.rawValue),
            URLQueryItem(name: "order", value: order.rawValue)
        ]
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category.rawValue))
        }
        if let minPrice = minPrice {
            queryItems.append(URLQueryItem(name: "min_price", value: String(minPrice)))
        }
        if let maxPrice = maxPrice {
            queryItems.append(URLQueryItem(name: "max_price", value: String(maxPrice)))
        }
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        var components = URLComponents(string: "/store/items")!
        components.queryItems = queryItems
        
        return try await apiClient.request(components.string ?? "/store/items", authenticated: true)
    }
    
    // MARK: - Get Store Item
    
    func getStoreItem(itemId: String) async throws -> StoreItem {
        return try await apiClient.request("/store/items/\(itemId)", authenticated: true)
    }
    
    // MARK: - Purchase Item
    
    func purchaseItem(itemId: String, quantity: Int = 1) async throws -> Purchase {
        let body = PurchaseCreate(itemId: itemId, quantity: quantity)
        let data = try JSONEncoder().encode(body)
        
        return try await apiClient.request(
            "/store/purchase",
            method: "POST",
            body: data,
            authenticated: true
        )
    }
    
    // MARK: - Get Purchase History
    
    func getPurchaseHistory(
        status: PurchaseStatus? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [Purchase] {
        var endpoint = "/store/purchases?limit=\(limit)&offset=\(offset)"
        if let status = status {
            endpoint += "&status=\(status.rawValue)"
        }
        
        return try await apiClient.request(endpoint, authenticated: true)
    }
    
    // MARK: - Get Featured Items
    
    func getFeaturedItems(limit: Int = 10) async throws -> [StoreItem] {
        return try await apiClient.request("/store/featured?limit=\(limit)", authenticated: true)
    }
    
    // MARK: - Get My Items
    
    func getMyItems() async throws -> [MyItemsResponse] {
        return try await apiClient.request("/store/my-items", authenticated: true)
    }
}

// MARK: - Store Models

struct StoreItem: Codable, Identifiable {
    let itemId: String
    let name: String
    let description: String
    let price: Double
    let category: StoreCategory
    let stock: Int
    let purchaseCount: Int
    let isFeatured: Bool
    let isLimited: Bool
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date?
    
    var id: String { itemId }
}

// Extension for UI properties
extension StoreItem {
    var iconName: String {
        switch category {
        case .gems: return "diamond.fill"
        case .filter: return "wand.and.stars"
        case .gift: return "gift.fill"
        case .vip: return "crown.fill"
        }
    }
}

struct PurchaseCreate: Codable {
    let itemId: String
    let quantity: Int
}

struct Purchase: Codable, Identifiable {
    let purchaseId: String
    let userId: String
    let itemId: String
    let quantity: Int
    let unitPrice: Double
    let totalPrice: Double
    let status: PurchaseStatus
    let createdAt: Date
    
    var id: String { purchaseId }
}

struct MyItemsResponse: Codable {
    let item: StoreItem
    let quantity: Int
    let lastPurchased: Date
}

// MARK: - Enums

enum SortOption: String {
    case name
    case price
    case popularity
    case createdAt = "created_at"
}

enum SortOrder: String {
    case asc
    case desc
}

enum PurchaseStatus: String, Codable {
    case pending
    case completed
    case failed
    case refunded
}