import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    MapView()
                case 2:
                    CameraPageView()
                case 3:
                    FriendsViewPage()
                case 4:
                    ProfileViewPage()
                default:
                    HomeView()
                }
            }
            BottomNavBarView(selectedTab: $selectedTab)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}
