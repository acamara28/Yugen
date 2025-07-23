import SwiftUI

struct MainTabController: View {
    @State private var selectedTab: TabItem = .home

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .home:
                    HomeView()
                case .map:
                    MapView()
                case .camera:
                    CreatePostView()
                case .network:
                    FriendsViewPage()
                case .profile:
                    ProfileViewPage()
                }
            }
            BottomNavBarView(selectedTab: $selectedTab)
        }
    }
}
