//
//  ActivityFeedView.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/26/25.
//


import SwiftUI
import Firebase

struct ActivityFeedView: View {
    @StateObject private var activityService = ActivityService()
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading activity...")
                        .padding()
                } else if activityService.activities.isEmpty {
                    Text("No recent activity from your friends.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(activityService.activities) { activity in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(activity.friendName)
                                    .font(.headline)
                                Spacer()
                                Text(activity.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Text("📍 \(activity.locationName)")
                                .font(.subheadline)

                            if !activity.tags.isEmpty {
                                HStack {
                                    ForEach(activity.tags.prefix(3), id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(6)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(6)
                                    }
                                }
                            }

                            if !activity.musicTitle.isEmpty {
                                Text("🎵 \(activity.musicTitle) - \(activity.musicArtist)")
                                    .font(.footnote)
                                    .foregroundColor(.purple)
                            }

                            Text("⭐️ Rated: \(activity.rating)/10")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Activity Feed")
            .onAppear {
                activityService.fetchFriendActivity {
                    isLoading = false
                }
            }
        }
    }
}
