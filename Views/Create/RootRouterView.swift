//
//  RootRouterView.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/22/25.
//


import SwiftUI
import FirebaseAuth

struct RootRouterView: View {
    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                MainTabController()
            } else {
                LoginView()
            }
        }
        .onAppear {
            self.isLoggedIn = Auth.auth().currentUser != nil
        }
    }
}
