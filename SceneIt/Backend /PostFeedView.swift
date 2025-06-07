import SwiftUI

struct PostFeedView: View {
    @StateObject private var postService = FirestorePostService.shared
    @State private var selectedPost: ScenicPost?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(postService.posts) { post in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(post.title)
                            .font(.headline)

                        if let url = URL(string: post.imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 250)
                                    .clipped()
                                    .cornerRadius(12)
                            } placeholder: {
                                ProgressView()
                                    .frame(height: 250)
                            }
                        }

                        if !post.labels.isEmpty {
                            HStack {
                                ForEach(post.labels.prefix(3), id: \ .self) { label in
                                    Text(label.capitalized)
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(6)
                                }
                            }
                        }

                        if !post.comment.isEmpty {
                            Text(post.comment)
                                .font(.subheadline)
                        }

                        if !post.musicTitle.isEmpty || !post.musicArtist.isEmpty {
                            HStack {
                                Image(systemName: "music.note")
                                Text("\(post.musicTitle) – \(post.musicArtist)")
                                    .font(.caption)
                            }
                        }

                        HStack {
                            Button { } label: { Image(systemName: "hand.thumbsup") }
                            Button { } label: { Image(systemName: "hand.thumbsdown") }
                            Button { selectedPost = post } label: { Image(systemName: "arrow.right.circle") }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
            }
            .padding()
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
        }
        .onAppear {
            postService.fetchRecentPosts()
        }
    }
}
