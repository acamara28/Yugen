import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct PostDetailView: View {
    let post: ScenicPost

    @State private var averageRating: Double?
    @State private var isLoading: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Full Image
                WebImage(url: URL(string: post.imageUrl))
                    .resizable()
                    .indicator(.activity)
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)

                // Labels
                HStack {
                    ForEach(post.labels, id: \.self) { label in
                        Text(label)
                            .padding(8)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Song
                if !post.musicTitle.isEmpty || !post.musicArtist.isEmpty {
                    HStack {
                        Image(systemName: "music.note")
                        Text("\(post.musicTitle) - \(post.musicArtist)")
                            .font(.subheadline)
                    }
                }

                // Comment / Memory
                Text(post.comment)
                    .font(.body)

                // Timestamp (optional display)
                Text("Posted on \(post.timestamp.formatted(.dateTime.month().day().year()))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}
