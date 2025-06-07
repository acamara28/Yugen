
import SwiftUI
import FirebaseAuth

struct CreatePostView: View {
    @State private var image: UIImage?
    @State private var comment: String = ""

    var body: some View {
        VStack {
            Text("Create Post")
                .font(.largeTitle)

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }

            TextField("Comment", text: $comment)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Submit") {
                if let user = Auth.auth().currentUser {
                    print("Post by user: \(user.uid)")
                }
            }
        }
        .padding()
    }
}
