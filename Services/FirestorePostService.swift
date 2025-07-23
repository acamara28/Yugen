// FirestorePostService.swift

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class FirestorePostService: ObservableObject {
    static let shared = FirestorePostService()

    @Published var posts: [PostModel] = []
    private let db = Firestore.firestore()

    // MARK: - Create a New Post
    func createPost(_ post: PostModel, completion: @escaping (Bool) -> Void) {
        do {
            var newPost = post
            newPost.createdAt = Date()
            _ = try db.collection("posts").addDocument(from: newPost)
            completion(true)
        } catch {
            print("❌ Failed to create post: \(error.localizedDescription)")
            completion(false)
        }
    }

    // MARK: - Fetch All Recent Posts
    func fetchRecentPosts(limit: Int = 30) {
        db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching posts: \(error.localizedDescription)")
                    return
                }

                self.posts = snapshot?.documents.compactMap { doc -> PostModel? in
                    try? doc.data(as: PostModel.self)
                } ?? []
            }
    }

    // MARK: - Fetch Posts by Location
    func fetchPosts(forLocation location: String, completion: @escaping ([PostModel]) -> Void) {
        db.collection("posts")
            .whereField("location", isEqualTo: location)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching location posts: \(error.localizedDescription)")
                    completion([])
                    return
                }

                let posts = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: PostModel.self)
                } ?? []
                completion(posts)
            }
    }

    // MARK: - Fetch Posts by User ID
    func fetchPostsByUser(userId: String, completion: @escaping (Result<[PostModel], Error>) -> Void) {
        db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    let posts = snapshot?.documents.compactMap {
                        try? $0.data(as: PostModel.self)
                    } ?? []
                    completion(.success(posts))
                }
            }
    }

    // MARK: - Upvote Post
    func upvote(post: PostModel) {
        guard let postId = post.id else { return }

        let ref = db.collection("posts").document(postId)
        ref.updateData(["upvotes": FieldValue.increment(Int64(1))])
    }

    // MARK: - Downvote Post
    func downvote(post: PostModel) {
        guard let postId = post.id else { return }

        let ref = db.collection("posts").document(postId)
        ref.updateData(["downvotes": FieldValue.increment(Int64(1))])
    }
}
