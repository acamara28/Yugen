import SwiftUI
import FirebaseAuth

struct SplashScreenView: View {
    @State private var isActive = false

    var body: some View {
        Group {
            if isActive {
                RootRouterView() // Main entry point after splash
            } else {
                VStack {
                    Image(systemName: "location.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(hex: "#B57EDC"))
                    Text("Yugen")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation {
                    isActive = true
                }
            }
        }
    }
}
