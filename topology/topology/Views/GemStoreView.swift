import SwiftUI

struct GemStoreView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var selectedCategory: StoreCategory = .gems
    @State private var showPurchaseAlert = false
    @State private var selectedItem: StoreItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // 내 보석 표시
            MyGemsView(gems: viewModel.myGems)
            
            // 카테고리 탭
            CategoryTabs(selectedCategory: $selectedCategory)
            
            // 상품 목록
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(itemsForCategory) { item in
                        StoreItemCard(
                            item: item,
                            onTap: {
                                selectedItem = item
                                showPurchaseAlert = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("보석 상점")
        .alert(isPresented: $showPurchaseAlert) {
            purchaseAlert
        }
    }
    
    var itemsForCategory: [StoreItem] {
        viewModel.storeItems.filter { $0.category == selectedCategory }
    }
    
    var purchaseAlert: Alert {
        guard let item = selectedItem else {
            return Alert(title: Text("오류"))
        }
        
        return Alert(
            title: Text("구매 확인"),
            message: Text("\(item.name)을(를) \(Int(item.price)) 보석에 구매하시겠습니까?"),
            primaryButton: .default(Text("구매")) {
                purchaseItem(item)
            },
            secondaryButton: .cancel(Text("취소"))
        )
    }
    
    func purchaseItem(_ item: StoreItem) {
        if viewModel.purchaseItem(item) {
            // 구매 성공
        } else {
            // 보석 부족
        }
    }
}

// 내 보석 뷰
struct MyGemsView: View {
    let gems: Int
    
    var body: some View {
        HStack {
            Image(systemName: "diamond.fill")
                .foregroundColor(.yellow)
                .font(.title2)
            
            Text("\(gems)")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: {
                // 보석 충전 페이지로 이동
            }) {
                Text("충전")
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }
}

// 카테고리 탭
struct CategoryTabs: View {
    @Binding var selectedCategory: StoreCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(StoreCategory.allCases, id: \.self) { category in
                    CategoryTab(
                        category: category,
                        isSelected: selectedCategory == category,
                        onTap: {
                            selectedCategory = category
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// 카테고리 탭 버튼
struct CategoryTab: View {
    let category: StoreCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var title: String {
        switch category {
        case .gems: return "보석"
        case .filter: return "필터"
        case .gift: return "선물"
        case .vip: return "VIP"
        }
    }
    
    var icon: String {
        switch category {
        case .gems: return "diamond.fill"
        case .filter: return "wand.and.stars"
        case .gift: return "gift.fill"
        case .vip: return "crown.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(isSelected ? Color.green : Color.clear)
            .cornerRadius(25)
        }
    }
}

// 상점 아이템 카드
struct StoreItemCard: View {
    let item: StoreItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 아이콘
                Image(systemName: item.iconName)
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .frame(height: 80)
                
                // 이름
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                // 설명
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30)
                
                // 가격
                HStack {
                    Image(systemName: "diamond.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    Text("\(Int(item.price))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.green)
                .cornerRadius(20)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
        }
    }
}

// 아이템 보관함 뷰
struct ItemStorageView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var selectedCategory: StoreCategory = .filter
    
    var body: some View {
        VStack(spacing: 0) {
            // 카테고리 탭
            CategoryTabs(selectedCategory: $selectedCategory)
            
            // 아이템 목록
            if filteredItems.isEmpty {
                EmptyItemView(category: selectedCategory)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(filteredItems) { item in
                            VStack {
                                Image(systemName: item.iconName)
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(12)
                                
                                Text(item.name)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("아이템 보관함")
    }
    
    var filteredItems: [StoreItem] {
        viewModel.ownedItems.filter { $0.category == selectedCategory }
    }
}

// 빈 아이템 뷰
struct EmptyItemView: View {
    let category: StoreCategory
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "tray.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(emptyMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: GemStoreView(viewModel: FriendsViewModel())) {
                Text("상점 가기")
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(20)
            }
            
            Spacer()
        }
    }
    
    var emptyMessage: String {
        switch category {
        case .filter: return "보유한 필터가 없습니다"
        case .gift: return "보유한 선물이 없습니다"
        case .vip: return "VIP 멤버십이 없습니다"
        case .gems: return "보유한 보석이 없습니다"
        }
    }
}