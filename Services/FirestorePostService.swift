// FirestorePostService.swift
import Foundation
import FirebaseFirestore
import FirebaseFirestore

class FirestorePostService: ObservableObject {
    static let shared = FirestorePostService()
    @Published var posts: [PostModel] = []

    private let db = Firestore.firestore()

    func fetchRecentPosts() {
        db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 25)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error fetching posts: \(error)")
                    return
                }

                self.posts = snapshot?.documents.compactMap {
                    try? $0.data(as: PostModel.self)
                } ?? []
            }
    }

    func fetchUserPosts(for userId: String, completion: @escaping (Result<[PostModel], Error>) -> Void) {
        db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                let posts = snapshot?.documents.compactMap {
                    try? $0.data(as: PostModel.self)
                } ?? []
                completion(.success(posts))
            }
    }

    func createPost(_ post: PostModel, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            _ = try db.collection("posts").addDocument(from: post)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}
