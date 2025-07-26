import SwiftUI
import MapKit

struct FriendsViewPage: View {
    @ObservedObject var service = FriendsLocationService.shared
    @State private var isLoading = true
    @State private var friendUIDs: [String] = []

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading friend spots...")
                        .padding()
                } else if service.contributions.isEmpty {
                    Text("No recent contributions from your friends.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(service.contributions) { contribution in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(contribution.friendName)
                                            .font(.headline)
                                        Spacer()
                                        Text("⭐️ \(contribution.rating)/10")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(contribution.locationName)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)

                                    if !contribution.tags.isEmpty {
                                        HStack {
                                            ForEach(contribution.tags.prefix(3), id: \.self) { tag in
                                                Text("#\(tag)")
                                                    .font(.caption)
                                                    .padding(6)
                                                    .background(Color.blue.opacity(0.2))
                                                    .cornerRadius(6)
                                            }
                                        }
                                    }

                                    if !contribution.musicTitle.isEmpty {
                                        Text("🎵 \(contribution.musicTitle) - \(contribution.musicArtist)")
                                            .font(.footnote)
                                            .foregroundColor(.purple)
                                    }

                                    Divider()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Friends' Spots")
            .onAppear {
                loadFriendUIDsAndFetch()
            }
        }
    }

    private func loadFriendUIDsAndFetch() {
        // TODO: Replace with actual Firestore fetch of current user’s friends
        friendUIDs = ["demoFriend1", "demoFriend2"] // ✅ Replace this when ready

        service.fetchFriendContributions(friendUIDs: friendUIDs) {
            isLoading = false
        }
    }
}
