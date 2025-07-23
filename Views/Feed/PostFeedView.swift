import SwiftUI

struct PostFeedView: View {
    @StateObject private var postService = FirestorePostService.shared
    @State private var selectedPost: PostModel?
    @State private var isRefreshing = false
    @State private var isFetchingMore = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(postService.posts) { post in
                        PostCardView(post: post)
                            .onTapGesture {
                                selectedPost = post
                            }
                            .onAppear {
                                if post == postService.posts.last {
                                    fetchMoreIfNeeded()
                                }
                            }
                    }

                    if isFetchingMore {
                        ProgressView()
                            .padding()
                    }
                }
                .padding()
                .refreshable {
                    await refreshPosts()
                }
            }
            .navigationTitle("Yugen Feed")
            .sheet(item: $selectedPost) { post in
                PostDetailView(post: post)
            }
            .onAppear {
                if postService.posts.isEmpty {
                    postService.fetchRecentPosts()
                }
            }
        }
    }

    private func refreshPosts() async {
        isRefreshing = true
        await postService.refreshPosts()
        isRefreshing = false
    }

    private func fetchMoreIfNeeded() {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        postService.fetchMorePosts {
            isFetchingMore = false
        }
    }
}
