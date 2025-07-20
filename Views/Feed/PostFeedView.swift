// PostFeedView.swift
import SwiftUI

struct PostFeedView: View {
    @StateObject private var postService = FirestorePostService.shared
    @State private var selectedPost: PostModel?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(postService.posts) { post in
                    PostCardView(post: post, onDetailTap: {
                        selectedPost = post
                    })
                }
            }
            .padding()
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
        }
        .onAppear {
            postService.fetchRecentPosts()
        }
    }
}
