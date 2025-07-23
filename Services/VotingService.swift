//
//  VotingService.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/21/25.
//


// MARK: - VotingService.swift

import Foundation
import FirebaseFirestore

final class VotingService {
    static let shared = VotingService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Upvote Post
    func upvote(postId: String, completion: ((Bool) -> Void)? = nil) {
        let postRef = db.collection("posts").document(postId)
        db.runTransaction { transaction, errorPointer in
            let snapshot = try transaction.getDocument(postRef)
            let currentVotes = snapshot.data()?["upvotes"] as? Int ?? 0
            transaction.updateData(["upvotes": currentVotes + 1], forDocument: postRef)
            return nil
        } completion: { _, error in
            if let error = error {
                print("❌ Failed to upvote: \(error.localizedDescription)")
                completion?(false)
            } else {
                completion?(true)
            }
        }
    }

    // MARK: - Downvote Post
    func downvote(postId: String, completion: ((Bool) -> Void)? = nil) {
        let postRef = db.collection("posts").document(postId)
        db.runTransaction { transaction, errorPointer in
            let snapshot = try transaction.getDocument(postRef)
            let currentVotes = snapshot.data()?["downvotes"] as? Int ?? 0
            transaction.updateData(["downvotes": currentVotes + 1], forDocument: postRef)
            return nil
        } completion: { _, error in
            if let error = error {
                print("❌ Failed to downvote: \(error.localizedDescription)")
                completion?(false)
            } else {
                completion?(true)
            }
        }
    }
}
