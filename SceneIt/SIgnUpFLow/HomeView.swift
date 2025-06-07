import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            TopBarView()
            
            TabView(selection: $selectedTab) {
                PostFeedView()
                    .tag(0)
                MapView()
                    .tag(1)
                CameraPageView()
                    .tag(2)
                NetworkPageView()
                    .tag(3)
                ProfilePageView()
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            BottomNavBarView()
        }
    }
}
