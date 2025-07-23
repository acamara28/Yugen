// MARK: - PostDetailView.swift

import SwiftUI
import SDWebImageSwiftUI

struct PostDetailView: View {
    let post: PostModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image
                WebImage(url: URL(string: post.imageUrl))
                    .resizable()
                    .placeholder {
                        ProgressView()
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
                    .cornerRadius(12)

                // Title & Username
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(.title)
                        .bold()

                    Text("Posted by \(post.username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Divider()

                // Labels
                if !post.labels.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Labels")
                            .font(.headline)

                        HStack {
                            ForEach(post.labels, id: \.self) { label in
                                Text(label.capitalized)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                // Music
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎵 Music")
                        .font(.headline)

                    Text("\(post.music.title) — \(post.music.artist)")
                        .font(.subheadline)
                }

                // Instructions
                if !post.specialInstruction.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note")
                            .font(.headline)

                        Text(post.specialInstruction)
                            .font(.body)
                    }
                }

                // Coordinates (optional)
                if let lat = post.latitude, let lon = post.longitude {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.headline)

                        Text("Lat: \(lat), Lon: \(lon)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // MARK: - Voting Buttons
                VotingButtonsView(
                    postId: post.id ?? "",
                    initialUpvotes: post.upvotes,
                    initialDownvotes: post.downvotes
                )

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
