import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ScenicLocation: Identifiable, Equatable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var posts: [PostModel] = []

    static func == (lhs: ScenicLocation, rhs: ScenicLocation) -> Bool {
        lhs.id == rhs.id
    }
}

struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    @State private var scenicLocations: [ScenicLocation] = []
    @State private var selectedLocation: ScenicLocation?
    @State private var selectedPost: PostModel?
    @State private var showPostDetail = false

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
                                            showPostDetail = true
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

                NavigationLink(destination: {
                    if let post = selectedPost {
                        PostDetailView(post: post)
                    }
                }, isActive: $showPostDetail) {
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Fetch Locations
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

    // MARK: - Fetch Posts Near Location
    private func fetchPostsFor(location: ScenicLocation) {
        let targetGeoPoint = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        let postsRef = Firestore.firestore().collection("posts")

        postsRef
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                guard error == nil else {
                    print("❌ Error fetching posts: \(error!.localizedDescription)")
                    return
                }

                let posts = snapshot?.documents.compactMap { doc -> PostModel? in
                    try? doc.data(as: PostModel.self)
                }.filter { post in
                    guard let postLocation = post.location else { return false }
                    let dist = distanceBetween(lat1: postLocation.latitude, lon1: postLocation.longitude, lat2: location.latitude, lon2: location.longitude)
                    return dist < 0.5 // 0.5 km radius
                } ?? []

                if let index = scenicLocations.firstIndex(of: location) {
                    scenicLocations[index].posts = posts
                    selectedLocation = scenicLocations[index]
                }
            }
    }

    // MARK: - Distance Function (Haversine)
    private func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0 // in km

        let dLat = (lat2 - lat1).degreesToRadians
        let dLon = (lon2 - lon1).degreesToRadians

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1.degreesToRadians) * cos(lat2.degreesToRadians) *
                sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}

// MARK: - Helpers
extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}

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
