import Foundation
import Firebase
import FirebaseFirestore

struct FriendActivity: Identifiable, Codable {
    let id: String
    let username: String
    let actionType: String
    let locationName: String
    let timestamp: Date
}

final class ActivityService: ObservableObject {
    static let shared = ActivityService()
    private let db = Firestore.firestore()

    // Fetch user’s friends' IDs
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

    // Fetch activity from all friend contributions
    func fetchFriendActivities(for currentUserID: String, completion: @escaping ([FriendActivity]) -> Void) {
        fetchFriendUIDs(for: currentUserID) { friendUIDs in
            self.db.collection("location_details").getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching locations: \(error.localizedDescription)")
                    completion([])
                    return
                }

                let locationDocs = snapshot?.documents ?? []
                var allActivities: [FriendActivity] = []
                let dispatchGroup = DispatchGroup()

                for locationDoc in locationDocs {
                    let locationId = locationDoc.documentID
                    let locationName = locationDoc.data()["name"] as? String ?? "Unknown Spot"

                    dispatchGroup.enter()
                    self.db.collection("location_details")
                        .document(locationId)
                        .collection("contributions")
                        .getDocuments { contribSnapshot, contribError in

                        if let contribError = contribError {
                            print("❌ Error fetching contributions: \(contribError.localizedDescription)")
                            dispatchGroup.leave()
                            return
                        }

                        let contributions = contribSnapshot?.documents ?? []
                        for doc in contributions {
                            let userId = doc.documentID
                            guard friendUIDs.contains(userId) else { continue }
                            let data = doc.data()
                            let activities = self.parseContributionData(data: data, locationName: locationName)
                            allActivities.append(contentsOf: activities)
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

    private func parseContributionData(data: [String: Any], locationName: String) -> [FriendActivity] {
        var results: [FriendActivity] = []

        let username = data["username"] as? String ?? "Friend"
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let idBase = UUID().uuidString

        if let tags = data["tags"] as? [String], !tags.isEmpty {
            results.append(FriendActivity(id: "\(idBase)-tags", username: username, actionType: "added tags", locationName: locationName, timestamp: timestamp))
        }
        if data["music"] as? [String: String] != nil {
            results.append(FriendActivity(id: "\(idBase)-music", username: username, actionType: "added music", locationName: locationName, timestamp: timestamp))
        }
        if let note = data["instructions"] as? String, !note.isEmpty {
            results.append(FriendActivity(id: "\(idBase)-note", username: username, actionType: "left a note", locationName: locationName, timestamp: timestamp))
        }
        if data["rating"] != nil {
            results.append(FriendActivity(id: "\(idBase)-rating", username: username, actionType: "rated this spot", locationName: locationName, timestamp: timestamp))
        }

        return results
    }
}
