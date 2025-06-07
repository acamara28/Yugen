//
//  MainTabController.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/16/25.
//


import SwiftUI

struct MainTabController: View {
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
                    CreatePostView() // Make sure this exists
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
    }
}
