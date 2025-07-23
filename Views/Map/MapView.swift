import SwiftUI
import MapKit
import FirebaseFirestore

struct ScenicLocation: Identifiable, Equatable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var posts: [PostModel] = []
}

struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    @State private var scenicLocations: [ScenicLocation] = []
    @State private var selectedLocation: ScenicLocation?
    @State private var selectedPost: PostModel?

    var body: some View {
        NavigationStack {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: scenicLocations) { location in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                        Button {
                            selectedLocation = location
                            fetchPostsFor(location: location)
                        } label: {
                            Image(systemName: "mappin.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(Color(hex: "#B57EDC")) // Lavender
                        }
                    }
                }
                .edgesIgnoringSafeArea(.all)
                .onAppear(perform: fetchLocations)

                // Bottom sheet for selected location
                if let location = selectedLocation, !location.posts.isEmpty {
                    VStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 10) {
                            Text(location.name)
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(location.posts) { post in
                                        VStack(alignment: .leading) {
                                            AsyncImage(url: URL(string: post.imageUrl)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Color.gray.opacity(0.2)
                                            }
                                            .frame(width: 120, height: 120)
                                            .clipped()
                                            .cornerRadius(10)

                                            Text(post.title)
                                                .font(.caption)
                                                .lineLimit(1)
                                        }
                                        .onTapGesture {
                                            selectedPost = post
                                        }
                                    }
                                }
                            }

                            Button("Close") {
                                selectedLocation = nil
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding()
                    }
                }

                // Navigation to full post
                if let post = selectedPost {
                    NavigationLink(destination: PostDetailView(post: post), isActive: .constant(true)) {
                        EmptyView()
                    }
                }
            }
        }
    }

    // Fetch all scenic location pins
    private func fetchLocations() {
        Firestore.firestore().collection("locations").getDocuments { snapshot, error in
            guard error == nil, let docs = snapshot?.documents else { return }

            scenicLocations = docs.compactMap { doc in
                let data = doc.data()
                guard let lat = data["latitude"] as? Double,
                      let lon = data["longitude"] as? Double,
                      let name = data["name"] as? String else { return nil }

                return ScenicLocation(
                    id: doc.documentID,
                    name: name,
                    latitude: lat,
                    longitude: lon
                )
            }
        }
    }

    // Fetch posts near this location
    private func fetchPostsFor(location: ScenicLocation) {
        Firestore.firestore().collection("posts")
            .whereField("location", isEqualTo: location.name)
            .order(by: "createdAt", descending: true)
            .limit(to: 5)
            .getDocuments { snapshot, error in
                guard error == nil else {
                    print("❌ Error fetching posts: \(error!.localizedDescription)")
                    return
                }

                let posts = snapshot?.documents.compactMap {
                    try? $0.data(as: PostModel.self)
                } ?? []

                if let index = scenicLocations.firstIndex(of: location) {
                    scenicLocations[index].posts = posts
                    selectedLocation = scenicLocations[index]
                }
            }
    }
}

// MARK: - Hex Color Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xff) / 255
        let g = Double((rgb >> 8) & 0xff) / 255
        let b = Double(rgb & 0xff) / 255
        
        self.init(red: r, green: g, blue: b)
    }
}
