import SwiftUI

struct PostCardView: View {
    let post: PostModel

    var body: some View {
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
                    ForEach(post.labels.prefix(3), id: \.self) { label in
                        Text(label.capitalized)
                            .font(.caption)
                            .padding(6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }

            if !post.specialInstruction.isEmpty {
                Text(post.specialInstruction)
                    .font(.subheadline)
            }

            if !post.music.title.isEmpty || !post.music.artist.isEmpty {
                HStack {
                    Image(systemName: "music.note")
                    Text("\(post.music.title) – \(post.music.artist)")
                        .font(.caption)
                }
            }

            HStack {
                Button { } label: { Image(systemName: "hand.thumbsup") }
                Button { } label: { Image(systemName: "hand.thumbsdown") }
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
