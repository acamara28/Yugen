
import SwiftUI
import FirebaseFirestore

struct ProfileViewPage: View {
    @State private var posts: [ScenicPost] = []

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts) { post in
                    PostCardView(post: post)
                }
            }
        }
        .onAppear {
            FirestorePostService.shared.fetchUserPosts { result in
                switch result {
                case .success(let posts):
                    self.posts = posts
                case .failure(let error):
                    print("Error loading posts: \(error)")
                }
            }
        }
    }
}
