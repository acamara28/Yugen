
import SwiftUI
import SDWebImageSwiftUI

struct PostCardView: View {
    let post: ScenicPost

    var body: some View {
        VStack(alignment: .leading) {
            WebImage(url: URL(string: post.imageUrl))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipped()

            Text(post.title)
                .font(.headline)

            Text(post.comment)
                .font(.subheadline)
        }
        .padding()
    }
}
