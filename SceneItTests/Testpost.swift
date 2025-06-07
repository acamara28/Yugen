import SwiftUI

struct TestPostView: View {
    var body: some View {
        Button(action: {
            let post = ScenicPost(
                id: nil,
                userId: "abc123",
                imageUrl: "https://your-test-image.jpg",
                title: "Golden Hour",
                labels: ["urban", "sunset"],
                musicTitle: "Good Days",
                musicArtist: "SZA",
                comment: "Best view from the west side",
                timestamp: Date()
            )
            FirestorePostService.shared.createPost(post) { result in
                switch result {
                case .success:
                    print("✅ Test post created successfully")
                case .failure(let error):
                    print("❌ Error creating post: \(error.localizedDescription)")
                }
            }
        }) {
            Text("Create Test Post")
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
    }
}
