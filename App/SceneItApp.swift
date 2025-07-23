import SwiftUI
import Firebase

@main
struct YugenApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
    }
}
