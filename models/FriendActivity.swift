import Foundation
import Firebase
import FirebaseFirestore

struct FriendActivity: Identifiable {
    var id: String
    var friendName: String
    var locationName: String
    var tags: [String]
    var musicTitle: String
    var musicArtist: String
    var rating: Int
    var timestamp: Date
}

class ActivityService: ObservableObject {
    @Published var activities: [FriendActivity] = []

    func fetchFriendActivity(completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let friendUIDs = ["demoFriend1", "demoFriend2"] // 🔁 Replace with dynamic UIDs

        var allActivities: [FriendActivity] = []
        let group = DispatchGroup()

        for friendUID in friendUIDs {
            db.collection("location_details")
                .getDocuments { snapshot, error in
                    guard let locationDocs = snapshot?.documents else { return }

                    for locationDoc in locationDocs {
                        let locationId = locationDoc.documentID
                        let contributionsRef = db
                            .collection("location_details")
                            .document(locationId)
                            .collection("contributions")

                        group.enter()
                        contributionsRef
                            .whereField("userId", isEqualTo: friendUID)
                            .order(by: "timestamp", descending: true)
                            .limit(to: 5)
                            .getDocuments { contribSnapshot, error in
                                defer { group.leave() }

                                guard let contribDocs = contribSnapshot?.documents else { return }

                                for doc in contribDocs {
                                    let data = doc.data()
                                    let activity = FriendActivity(
                                        id: doc.documentID,
                                        friendName: data["username"] as? String ?? "Unknown",
                                        locationName: data["locationName"] as? String ?? "Unknown Spot",
                                        tags: data["tags"] as? [String] ?? [],
                                        musicTitle: data["musicTitle"] as? String ?? "",
                                        musicArtist: data["musicArtist"] as? String ?? "",
                                        rating: data["rating"] as? Int ?? 0,
                                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                                    )
                                    allActivities.append(activity)
                                }
                            }
                    }
                }
        }

        group.notify(queue: .main) {
            self.activities = allActivities.sorted(by: { $0.timestamp > $1.timestamp })
            completion()
        }
    }
}
