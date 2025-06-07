import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var userPlacemark: CLPlacemark?
    @Published var locationError: String?
    @Published var nearbyScenicLocation: ScenicLocation? // ✅ Trigger for Check-In UI

    var currentLocation: CLLocation? {
        return userLocation
    }

    private var cancellables = Set<AnyCancellable>()
    private let proximityRadius: Double = 100 // meters

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func startTracking() {
        locationError = nil
        manager.startUpdatingLocation()
    }

    func requestLocationOnce() {
        locationError = nil
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.userLocation = location
                self.reverseGeocode(location: location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }

    private func reverseGeocode(location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.locationError = error.localizedDescription
                } else {
                    self.userPlacemark = placemarks?.first
                }
            }
        }
    }

    // ✅ Proximity Check
    func checkProximity(to scenicLocations: [ScenicLocation]) {
        guard let currentLocation = self.userLocation else { return }

        for location in scenicLocations {
            let destination = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let distance = currentLocation.distance(from: destination)

            if distance <= proximityRadius {
                // ✅ User is near a known scenic location
                DispatchQueue.main.async {
                    self.nearbyScenicLocation = location
                }
                return
            }
        }

        // ❌ Not near any location
        DispatchQueue.main.async {
            self.nearbyScenicLocation = nil
        }
    }
}
