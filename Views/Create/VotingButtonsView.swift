//
//  VotingButtonsView.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/21/25.
//


// MARK: - VotingButtonsView.swift

import SwiftUI

struct VotingButtonsView: View {
    let postId: String
    let initialUpvotes: Int
    let initialDownvotes: Int

    @State private var upvotes: Int
    @State private var downvotes: Int

    init(postId: String, initialUpvotes: Int, initialDownvotes: Int) {
        self.postId = postId
        self.initialUpvotes = initialUpvotes
        self.initialDownvotes = initialDownvotes
        _upvotes = State(initialValue: initialUpvotes)
        _downvotes = State(initialValue: initialDownvotes)
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                VotingService.shared.upvote(postId: postId) { success in
                    if success { upvotes += 1 }
                }
            }) {
                HStack {
                    Image(systemName: "hand.thumbsup")
                    Text("\(upvotes)")
                }
            }

            Button(action: {
                VotingService.shared.downvote(postId: postId) { success in
                    if success { downvotes += 1 }
                }
            }) {
                HStack {
                    Image(systemName: "hand.thumbsdown")
                    Text("\(downvotes)")
                }
            }
        }
        .font(.caption)
        .foregroundColor(.gray)
    }
}
