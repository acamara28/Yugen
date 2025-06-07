import SwiftUI
import CoreLocation

struct HomeView: View {
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var firestoreService = FirestoreLocationService.shared

    @State private var showAddDetails = false
    @State private var selectedLocationId: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 🔔 Scenic Location Banner
                if let nearby = locationManager.nearbyScenicLocation {
                    VStack(spacing: 8) {
                        Text("📍 You're at a scenic location!")
                            .font(.headline)
                        Text("You’re near: \(nearby.id)")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Button("Rate this location") {
                            selectedLocationId = nearby.id
                            showAddDetails = true
                        }

                        Button("Add Label, Music, or Notes") {
                            selectedLocationId = nearby.id
                            showAddDetails = true
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(12)
                    .padding()
                    .transition(.move(edge: .top))
                }

                // 🌍 Main Feed of Posts
                Divider()
                PostFeedView() // 📷 Social feed with scenic posts

                Spacer()
            }
            .navigationTitle("Yugen")
        }
        .sheet(isPresented: $showAddDetails) {
            if let id = selectedLocationId {
                AddDetailsView(locationId: id)
            }
        }
        .task {
            firestoreService.fetchScenicLocations()
        }
        .onReceive(firestoreService.$scenicLocations) { newLocations in
            locationManager.checkProximity(to: newLocations)
        }
    }
}
