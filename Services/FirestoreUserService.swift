// FirestoreUserService.swift

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFirestoreSwift

final class FirestoreUserService: ObservableObject {
    static let shared = FirestoreUserService()
    private let db = Firestore.firestore()
    private init() {}

    @Published var currentUser: UserModel?

    // MARK: - Fetch current user (logged-in user)
    func fetchCurrentUser(completion: @escaping (UserModel?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching user: \(error.localizedDescription)")
                completion(nil)
                return
            }

            if let user = try? snapshot?.data(as: UserModel.self) {
                DispatchQueue.main.async {
                    self.currentUser = user
                    completion(user)
                }
            } else {
                print("❌ Failed to decode UserModel")
                completion(nil)
            }
        }
    }

    // MARK: - Fetch user by UID (used in profile view or friends)
    func fetchUser(uid: String, completion: @escaping (UserModel?) -> Void) {
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching user by uid: \(error.localizedDescription)")
                completion(nil)
                return
            }

            if let user = try? snapshot?.data(as: UserModel.self) {
                completion(user)
            } else {
                print("❌ Failed to decode UserModel from uid \(uid)")
                completion(nil)
            }
        }
    }

    // MARK: - Create a user document
    func createUser(_ user: UserModel, completion: ((Bool) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(false)
            return
        }

        do {
            try db.collection("users").document(uid).setData(from: user) { error in
                if let error = error {
                    print("❌ Error creating user: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    self.currentUser = user
                    completion?(true)
                }
            }
        } catch {
            print("❌ Error encoding user: \(error.localizedDescription)")
            completion?(false)
        }
    }

    // MARK: - Update visited locations
    func addVisitedLocation(_ locationId: String, for userId: String) {
        let ref = db.collection("users").document(userId)
        ref.updateData([
            "visitedLocations": FieldValue.arrayUnion([locationId])
        ]) { error in
            if let error = error {
                print("❌ Error updating visited locations: \(error.localizedDescription)")
            }
        }
    }
}
