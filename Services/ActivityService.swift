import Foundation
import Firebase
import FirebaseFirestore

struct FriendActivity: Identifiable {
    let id: String // Usually the Firestore document ID
    let username: String
    let actionType: String
    let locationName: String
    let timestamp: Date
}

class ActivityService: ObservableObject {
    static let shared = ActivityService()

    private let db = Firestore.firestore()

    /// Replace with however you're storing friends (e.g., under `/users/{uid}/friends`)
    func fetchFriendUIDs(for currentUserID: String, completion: @escaping ([String]) -> Void) {
        db.collection("users").document(currentUserID).collection("friends").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching friends: \(error.localizedDescription)")
                completion([])
                return
            }

            let friendUIDs = snapshot?.documents.map { $0.documentID } ?? []
            completion(friendUIDs)
        }
    }

    /// Fetches all friend activity across scenic locations
    func fetchFriendActivities(for currentUserID: String, completion: @escaping ([FriendActivity]) -> Void) {
        fetchFriendUIDs(for: currentUserID) { friendUIDs in
            self.db.collection("location_details").getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching location details: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let locationDocs = snapshot?.documents else {
                    completion([])
                    return
                }

                var allActivities: [FriendActivity] = []
                let dispatchGroup = DispatchGroup()

                for locationDoc in locationDocs {
                    let locationId = locationDoc.documentID
                    let locationName = locationDoc.data()["name"] as? String ?? "Unknown Spot"

                    dispatchGroup.enter()

                    self.db.collection("location_details").document(locationId).collection("contributions").getDocuments { contribSnapshot, contribError in
                        if let contribError = contribError {
                            print("❌ Error fetching contributions: \(contribError.localizedDescription)")
                            dispatchGroup.leave()
                            return
                        }

                        let contributions = contribSnapshot?.documents ?? []

                        for doc in contributions {
                            let userId = doc.documentID
                            if friendUIDs.contains(userId) {
                                let data = doc.data()
                                let username = data["username"] as? String ?? "Friend"
                                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()

                                var actions: [String] = []

                                if let tags = data["tags"] as? [String], !tags.isEmpty {
                                    actions.append("added tags")
                                }
                                if let _ = data["music"] as? [String: String] {
                                    actions.append("added music")
                                }
                                if let instructions = data["instructions"] as? String, !instructions.isEmpty {
                                    actions.append("left a note")
                                }
                                if let _ = data["rating"] as? Int {
                                    actions.append("rated this spot")
                                }

                                for action in actions {
                                    let activity = FriendActivity(
                                        id: UUID().uuidString,
                                        username: username,
                                        actionType: action,
                                        locationName: locationName,
                                        timestamp: timestamp
                                    )
                                    allActivities.append(activity)
                                }
                            }
                        }

                        dispatchGroup.leave()
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    let sorted = allActivities.sorted { $0.timestamp > $1.timestamp }
                    completion(sorted)
                }
            }
        }
    }
}
