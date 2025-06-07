import Foundation
import FirebaseFirestore
import CoreLocation

struct ScenicLocation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    var averageRating: Double?
}

class FirestoreLocationService: ObservableObject {
    static let shared = FirestoreLocationService()

    @Published var scenicLocations: [ScenicLocation] = []

    private let db = Firestore.firestore()

    private init() {}

    func fetchScenicLocations() {
        db.collection("location_details").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching locations: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("⚠️ No documents found.")
                return
            }

            var locations: [ScenicLocation] = []

            for doc in documents {
                let data = doc.data()
                let id = doc.documentID

                if let geo = data["coordinate"] as? GeoPoint {
                    let coordinate = CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude)
                    let ratingTotal = data["ratingTotal"] as? Double ?? 0
                    let ratingCount = data["ratingCount"] as? Double ?? 0
                    let average = ratingCount > 0 ? (ratingTotal / ratingCount) : nil

                    let location = ScenicLocation(id: id, coordinate: coordinate, averageRating: average)
                    locations.append(location)
                }
            }

            DispatchQueue.main.async {
                self.scenicLocations = locations
                print("✅ Loaded \(locations.count) scenic locations")
            }
        }
    }
}
