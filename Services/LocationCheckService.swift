import Foundation
import CoreLocation
import FirebaseFirestore

class LocationCheckService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    
    @Published var nearbyLocationID: String? = nil
    @Published var isChecking = false
    @Published var locationError: String?

    private var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        currentLocation = latest
    }

    func checkProximityToLocations(radiusMeters: Double = 75.0) {
        guard let userLocation = currentLocation else {
            locationError = "Location not available"
            return
        }

        isChecking = true
        db.collection("locations").getDocuments { snapshot, error in
            self.isChecking = false
            if let error = error {
                self.locationError = "Error fetching locations: \(error.localizedDescription)"
                return
            }

            guard let documents = snapshot?.documents else { return }

            for doc in documents {
                let data = doc.data()
                if let geo = data["coordinates"] as? GeoPoint {
                    let location = CLLocation(latitude: geo.latitude, longitude: geo.longitude)
                    let distance = userLocation.distance(from: location)
                    if distance <= radiusMeters {
                        self.nearbyLocationID = doc.documentID
                        return
                    }
                }
            }

            self.nearbyLocationID = nil
        }
    }
}
