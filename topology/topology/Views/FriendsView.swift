import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showAddFriend = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 친구/즐겨찾기 탭 선택
                HStack {
                    Button(action: {
                        viewModel.selectedTab = 0
                    }) {
                        Text("친구")
                            .font(.headline)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(viewModel.selectedTab == 0 ? Color.green : Color.clear)
                            .foregroundColor(viewModel.selectedTab == 0 ? .white : .gray)
                            .cornerRadius(20)
                    }
                    
                    Button(action: {
                        viewModel.selectedTab = 1
                    }) {
                        Text("즐겨찾기")
                            .font(.headline)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(viewModel.selectedTab == 1 ? Color.green : Color.clear)
                            .foregroundColor(viewModel.selectedTab == 1 ? .white : .gray)
                            .cornerRadius(20)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 친구 초대 배너
                InviteBanner(viewModel: viewModel)
                
                // 목록 표시
                if viewModel.selectedTab == 0 {
                    FriendsListView(viewModel: viewModel)
                } else {
                    FavoritesListView(viewModel: viewModel)
                }
            }
            .navigationTitle("친구")
            .navigationBarItems(trailing: Button(action: {
                showAddFriend = true
            }) {
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.green)
            })
            .searchable(text: $viewModel.searchText, prompt: "이름으로 검색")
            .sheet(isPresented: $showAddFriend) {
                InviteFriendView(viewModel: viewModel)
            }
        }
    }
}

// 친구 초대 배너
struct InviteBanner: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var showInviteView = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("친구 초대하실?")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("초대하면 상품필터 드려요!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                    
                    Text("👤")
                        .font(.title)
                }
                
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                    
                    Text("💎")
                        .font(.title2)
                }
                
                Button(action: {
                    showInviteView = true
                }) {
                    HStack {
                        Text("더 보기")
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(15)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
        .padding(.horizontal)
        .padding(.top, 8)
        .sheet(isPresented: $showInviteView) {
            InviteFriendView(viewModel: viewModel)
        }
    }
}

// 친구 목록 뷰
struct FriendsListView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 활동 섹션
                SectionHeader(title: "활동")
                
                // 친구 관리 메뉴
                FriendManagementMenu(viewModel: viewModel)
                
                // 친구 목록
                if viewModel.filteredFriends.isEmpty {
                    EmptyFriendsView(viewModel: viewModel)
                } else {
                    ForEach(viewModel.filteredFriends) { friend in
                        NavigationLink(destination: FriendDetailView(friend: friend, viewModel: viewModel)) {
                            FriendRow(friend: friend)
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// 즐겨찾기 목록 뷰
struct FavoritesListView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        ScrollView {
            if viewModel.favoriteFriends.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "star.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("즐겨찾기한 친구가 없습니다")
                        .foregroundColor(.gray)
                    
                    Text("친구를 즐겨찾기에 추가해보세요")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding()
                .frame(height: 300)
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.favoriteFriends) { friend in
                        NavigationLink(destination: FriendDetailView(friend: friend, viewModel: viewModel)) {
                            FavoriteRow(friend: friend)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
}

// 친구 관리 메뉴
struct FriendManagementMenu: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 내 보석
            NavigationLink(destination: GemStoreView(viewModel: viewModel)) {
                HStack {
                    Text("내 보석")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "diamond.fill")
                        .foregroundColor(.yellow)
                    
                    Text("\(viewModel.myGems)")
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                    
                    Text("상점")
                        .foregroundColor(.yellow)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
            
            // 아이템 보관함
            NavigationLink(destination: ItemStorageView(viewModel: viewModel)) {
                HStack {
                    Text("아이템 보관함")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 숨김친구 관리
            NavigationLink(destination: HiddenFriendsView(viewModel: viewModel)) {
                HStack {
                    Text("숨김친구 관리")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !viewModel.hiddenFriends.isEmpty {
                        Text("\(viewModel.hiddenFriends.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(10)
                            .padding(.trailing, 8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
            
            // 차단친구 관리
            NavigationLink(destination: BlockedFriendsView(viewModel: viewModel)) {
                HStack {
                    Text("차단친구 관리")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !viewModel.blockedFriends.isEmpty {
                        Text("\(viewModel.blockedFriends.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(10)
                            .padding(.trailing, 8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
    }
}

// 섹션 헤더
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3))
        .padding(.top, 8)
    }
}

// 빈 친구 목록 뷰
struct EmptyFriendsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var showInviteView = false
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("친구가 없습니다")
                .foregroundColor(.gray)
            
            Button(action: {
                showInviteView = true
            }) {
                Text("친구 초대하기")
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(20)
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 300)
        .sheet(isPresented: $showInviteView) {
            InviteFriendView(viewModel: viewModel)
        }
    }
}

// 친구 행 뷰
struct FriendRow: View {
    let friend: Friend
    
    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Text("👤")
                    .font(.title3)
            }
            .overlay(
                Circle()
                    .fill(friend.isOnline ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .offset(x: 18, y: -18)
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
                }
                
                Text("\(friend.age)세 • \(friend.country)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 온라인 상태
            VStack(alignment: .trailing, spacing: 4) {
                Text(friend.isOnline ? "온라인" : friend.lastSeen)
                    .font(.caption)
                    .foregroundColor(friend.isOnline ? .green : .gray)
                
                HStack(spacing: 12) {
                    NavigationLink(destination: ChatView(friend: friend)) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.gray)
                    }
                    
                    NavigationLink(destination: VideoCallView(friend: friend)) {
                        Image(systemName: "video.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
}

// 즐겨찾기 행 뷰
struct FavoriteRow: View {
    let friend: Friend
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4))
                
                VStack(spacing: 12) {
                    // 프로필 이미지
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                        
                        Text("👤")
                            .font(.system(size: 40))
                    }
                    .overlay(
                        Circle()
                            .fill(friend.isOnline ? Color.green : Color.gray)
                            .frame(width: 16, height: 16)
                            .offset(x: 32, y: -32)
                    )
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(friend.name)
                                .font(.headline)
                            
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                        }
                        
                        Text("\(friend.age)세 • \(friend.country)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // 온라인 상태
                    Text(friend.isOnline ? "온라인" : friend.lastSeen)
                        .font(.caption)
                        .foregroundColor(friend.isOnline ? .green : .gray)
                    
                    // 버튼 행
                    HStack(spacing: 20) {
                        NavigationLink(destination: ChatView(friend: friend)) {
                            VStack {
                                Image(systemName: "message.fill")
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
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
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.green)
                                    .clipShape(Circle())
                                
                                Text("통화")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(height: 240)
    }
}