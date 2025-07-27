//
//  TabItem.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/26/25.
//


import SwiftUI

enum TabItem: String, CaseIterable {
    case home = "house"
    case map = "map"
    case camera = "camera"
    case network = "person.2"
    case profile = "person.crop.circle"
}

struct BottomNavBarView: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        HStack {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Spacer()
                Button(action: {
                    selectedTab = tab
                }) {
                    Image(systemName: tab.rawValue)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(selectedTab == tab ? .purple : .gray)
                        .padding(10)
                }
                Spacer()
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 20)
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .shadow(radius: 3)
    }
}
