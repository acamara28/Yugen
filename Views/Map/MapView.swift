import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @StateObject private var firestoreService = FirestoreLocationService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // Default: NYC
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: firestoreService.scenicLocations) { location in
            MapAnnotation(coordinate: location.coordinate) {
                VStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color.purple)
                        .font(.title)
                        .onTapGesture {
                            // Optional: Present PostDetailView or a custom preview
                        }

                    Text("Scenic Spot")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(4)
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
