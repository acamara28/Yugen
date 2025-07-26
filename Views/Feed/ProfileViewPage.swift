import SwiftUI
import SDWebImageSwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileViewPage: View {
    @StateObject private var userService = FirestoreUserService.shared
    @State private var userPosts: [PostModel] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Profile Header
                    if let user = userService.currentUser {
                        VStack(spacing: 12) {
                            if let urlStr = user.profileImageUrl,
                               let url = URL(string: urlStr) {
                                WebImage(url: url)
                                    .resizable()
                                    .placeholder { ProgressView() }
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                            }

                            Text(user.username)
                                .font(.title2)
                                .bold()

                            if let name = user.fullName {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                VStack {
                                    Text("\(user.visitedLocations.count)")
                                        .font(.title3)
                                        .bold()
                                    Text("Visited Spots")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.top)
                    }

                    Divider()

                    // MARK: - Posts Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Posts")
                            .font(.headline)

                        if isLoading {
                            ProgressView("Loading posts...")
                                .padding()
                        } else if userPosts.isEmpty {
                            Text("You haven’t posted yet.")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                                .padding()
                        } else {
                            ForEach(userPosts, id: \.id) { post in
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        WebImage(url: URL(string: post.imageUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 200)
                                            .cornerRadius(10)
                                            .clipped()

                                        Text(post.title)
                                            .font(.subheadline)
                                            .bold()
                                            .padding(.leading, 4)

                                        Text("At: \(post.locationName ?? "Unknown")")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.leading, 4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("My Profile")
            .onAppear(perform: loadUserPosts)
        }
    }

    // MARK: - Load Posts by Current User
    private func loadUserPosts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                isLoading = false
                if let docs = snapshot?.documents {
                    self.userPosts = docs.compactMap { try? $0.data(as: PostModel.self) }
                } else {
                    print("❌ Error fetching profile posts: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
    }
}
