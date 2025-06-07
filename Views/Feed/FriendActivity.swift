

import Foundation
import Firebase
import FirebaseAuth

struct FriendActivity: Identifiable {
    let id: String
    let username: String
    let locationName: String
    let tags: [String]
    let music: MusicInfo?
    let rating: Int?
    let timestamp: Date?
}

class ActivityService: ObservableObject {
    static let shared = ActivityService()
    @Published var activities: [FriendActivity] = []

    private let db = Firestore.firestore()

    func fetchFriendActivity(for userId: String) {
        // Replace with real friends list fetch if needed
        let friendsRef = db.collection("users").document(userId).collection("friends")

        friendsRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching friends: \(error.localizedDescription)")
                return
            }

            guard let docs = snapshot?.documents else { return }
            let friendIds = docs.map { $0.documentID }

            self.activities = [] // Reset before fetching

            for friendId in friendIds {
                self.db.collection("location_details")
                    .getDocuments { locationSnapshot, error in
                        guard let locations = locationSnapshot?.documents else { return }

                        for locationDoc in locations {
                            let locationId = locationDoc.documentID
                            let contributionRef = self.db.collection("location_details")
                                .document(locationId)
                                .collection("contributions")
                                .document(friendId)

                            contributionRef.getDocument { docSnap, error in
                                if let data = docSnap?.data(), docSnap?.exists == true {
                                    let username = friendId // Replace with username lookup if needed
                                    let tags = data["tags"] as? [String] ?? []
                                    let rating = data["rating"] as? Int
                                    let musicDict = data["music"] as? [String: String]
                                    let music = MusicInfo(
                                        title: musicDict?["title"] ?? "",
                                        artist: musicDict?["artist"] ?? ""
                                    )
                                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()

                                    let activity = FriendActivity(
                                        id: "\(friendId)_\(locationId)",
                                        username: username,
                                        locationName: locationId,
                                        tags: tags,
                                        music: music,
                                        rating: rating,
                                        timestamp: timestamp
                                    )

                                    DispatchQueue.main.async {
                                        self.activities.append(activity)
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
}
