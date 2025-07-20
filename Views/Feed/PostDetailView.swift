import SwiftUI

struct PostDetailView: View {
    let post: PostModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = URL(string: post.imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                    } placeholder: {
                        ProgressView()
                    }
                }

                Text(post.title)
                    .font(.title)
                    .bold()

                Text("📍 Location: \(post.location)")
                    .font(.subheadline)

                if !post.labels.isEmpty {
                    HStack {
                        ForEach(post.labels, id: \.self) { label in
                            Text(label)
                                .font(.caption)
                                .padding(6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                }

                Text("📝 Instructions: \(post.specialInstruction)")
                    .font(.body)

                Text("🎶 Song: \(post.music.title) - \(post.music.artist)")
                    .font(.footnote)

                HStack {
                    Text("👍 \(post.upvotes)")
                    Text("👎 \(post.downvotes)")
                }
                .font(.footnote)
                .foregroundColor(.gray)

                if let createdAt = post.createdAt {
                    Text("🕒 Posted on \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Post Details")
    }
}
