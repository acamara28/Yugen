import SwiftUI

struct TestPostView: View {
    var body: some View {
        Button("Create Dummy Post") {
            let dummyMusic = MusicInfo(title: "Good Days", artist: "SZA")
            
            let post = PostModel(
                id: nil,
                userId: "abc123",
                username: "testuser",
                location: "Brooklyn, NY",
                title: "Golden Hour",
                labels: ["urban", "sunset"],
                specialInstruction: "Best view from the west side",
                music: dummyMusic,
                upvotes: 0,
                downvotes: 0,
                imageUrl: "https://your-test-image.jpg",
                createdAt: Date(),
                latitude: 40.6782,
                longitude: -73.9442
            )

            FirestorePostService.shared.createPost(post) { result in
                switch result {
                case .success:
                    print("✅ Dummy post uploaded")
                case .failure(let error):
                    print("❌ Upload failed: \(error.localizedDescription)")
                }
            }
        }
        .padding()
    }
}
