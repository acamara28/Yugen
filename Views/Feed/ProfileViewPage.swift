import SwiftUI
import FirebaseAuth

struct ProfileViewPage: View {
    @State private var posts: [PostModel] = []

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts) { post in
                    PostCardView(post: post)
                }
            }
        }
        .onAppear {
            if let userId = Auth.auth().currentUser?.uid {
                FirestorePostService.shared.fetchUserPosts(for: userId) { result in
                    switch result {
                    case .success(let posts):
                        self.posts = posts
                    case .failure(let error):
                        print("Error loading posts: \(error)")
                    }
                }
            } else {
                print("❌ No logged-in user")
            }
        }
    }
}
