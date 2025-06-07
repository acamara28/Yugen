import SwiftUI

struct SplashScreenView: View {
    @State private var fadeOut = false
    @State private var showLogin = false

    var body: some View {
        ZStack {
            Image("sceneit_icon_SplashScreen")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .opacity(fadeOut ? 0 : 1)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    fadeOut = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showLogin = true
                }
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginScreenView()
        }
    }
}
