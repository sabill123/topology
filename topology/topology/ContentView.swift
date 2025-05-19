import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 2
    
    var body: some View {
        if authManager.isLoading {
            // Loading view
            VStack {
                ProgressView()
                Text("Loading...")
                    .padding(.top)
            }
        } else if authManager.isAuthenticated {
            // Main app view
            TabView(selection: $selectedTab) {
                FriendsView()
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text("친구")
                    }
                    .tag(0)
                
                ChatsView()
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("채팅")
                    }
                    .tag(1)
                
                HomeView()
                    .tabItem {
                        Image(systemName: "video.fill")
                        Text("홈")
                    }
                    .tag(2)
                
                RecentCallsView()
                    .tabItem {
                        Image(systemName: "clock.fill")
                        Text("기록")
                    }
                    .tag(3)
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("프로필")
                    }
                    .tag(4)
            }
            .accentColor(.green)
            .preferredColorScheme(.dark)
            .onAppear {
                // Connect WebSocket when app appears
                WebSocketService.shared.connect()
            }
        } else {
            // Login view
            LoginView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}