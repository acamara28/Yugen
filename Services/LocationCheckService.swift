import Foundation
import CoreLocation
import FirebaseFirestore

final class LocationCheckService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationCheckService()

    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private let checkInRadius: Double = 75 // meters

    @Published var nearbyLocationId: String?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        checkProximity(to: currentLocation)
    }

    // MARK: - Check Proximity to Locations in Firestore
    func checkProximity(to currentLocation: CLLocation) {
        db.collection("locations").getDocuments { snapshot, error in
            guard error == nil, let documents = snapshot?.documents else { return }

            for doc in documents {
                let data = doc.data()
                if let lat = data["latitude"] as? CLLocationDegrees,
                   let lon = data["longitude"] as? CLLocationDegrees {
                    let location = CLLocation(latitude: lat, longitude: lon)
                    let distance = currentLocation.distance(from: location)
                    if distance <= self.checkInRadius {
                        DispatchQueue.main.async {
                            self.nearbyLocationId = doc.documentID
                        }
                        break
                    }
                }
            }
        }
    }

    // MARK: - Trigger Check-in Logic (UI can observe nearbyLocationId)
    func clearNearbyLocation() {
        self.nearbyLocationId = nil
    }

    // MARK: - Check-in Function
    func logUserCheckIn(userId: String, locationId: String, completion: @escaping (Bool) -> Void) {
        let contributionData: [String: Any] = [
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("location_details")
            .document(locationId)
            .collection("checkins")
            .document(userId)
            .setData(contributionData, merge: true) { error in
                if let error = error {
                    print("❌ Failed to check-in: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ User checked in to location \(locationId)")
                    completion(true)
                }
            }
    }
}
