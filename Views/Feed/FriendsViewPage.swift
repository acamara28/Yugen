

import SwiftUI
import MapKit

struct FriendsViewPage: View {
    @ObservedObject var service = FriendsLocationService.shared

    var body: some View {
        NavigationView {
            List(service.contributions) { contribution in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(contribution.friendName)
                            .font(.headline)
                        Spacer()
                        Text("⭐️ \(contribution.rating)/10")
                    }

                    Text(contribution.locationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

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
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Friends' Spots")
        }
        .onAppear {
            service.fetchFriendContributions(friendUIDs: ["demoFriend1", "demoFriend2"])
        }
    }
}
