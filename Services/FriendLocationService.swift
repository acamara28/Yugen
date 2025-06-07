import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct FriendContribution: Identifiable {
    let id: String // Firestore doc ID
    let friendName: String
    let locationId: String
    let locationName: String
    let tags: [String]
    let rating: Int
    let musicTitle: String
    let musicArtist: String
    let coordinate: CLLocationCoordinate2D
}

class FriendsLocationService: ObservableObject {
    static let shared = FriendsLocationService()
    private let db = Firestore.firestore()
    
    @Published var contributions: [FriendContribution] = []

    func fetchFriendContributions(friendUIDs: [String]) {
        contributions = []

        for uid in friendUIDs {
            db.collection("location_details").getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for doc in documents {
                        let locationId = doc.documentID
                        let locationData = doc.data()

                        if let geoPoint = locationData["coordinate"] as? GeoPoint {
                            let locationCoordinate = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)

                            self.db.collection("location_details")
                                .document(locationId)
                                .collection("contributions")
                                .document(uid)
                                .getDocument { snap, err in
                                    guard let data = snap?.data(), err == nil else { return }

                                    let contribution = FriendContribution(
                                        id: snap!.documentID,
                                        friendName: uid, // swap with display name if you store it elsewhere
                                        locationId: locationId,
                                        locationName: locationData["name"] as? String ?? "Scenic Spot",
                                        tags: data["tags"] as? [String] ?? [],
                                        rating: data["rating"] as? Int ?? 0,
                                        musicTitle: (data["music"] as? [String: String])?["title"] ?? "",
                                        musicArtist: (data["music"] as? [String: String])?["artist"] ?? "",
                                        coordinate: locationCoordinate
                                    )

                                    DispatchQueue.main.async {
                                        self.contributions.append(contribution)
                                    }
                                }
                        }
                    }
                }
            }
        }
    }
}
