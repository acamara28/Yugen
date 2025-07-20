import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @StateObject private var firestoreService = FirestoreLocationService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        Map(initialPosition: .region(region)) {
            ForEach(firestoreService.scenicLocations) { location in
                Annotation("Scenic Spot", coordinate: location.coordinate) {
                    VStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title)
                            .onTapGesture {
                                // Optional: Show post details
                            }

                        Text("Scenic Spot")
                            .font(.caption)
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            firestoreService.fetchScenicLocations()
        }
        .navigationTitle("Explore Map")
        .navigationBarTitleDisplayMode(.inline)
    }
}
