import Foundation
import FirebaseFirestore

struct PostModel: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var username: String
    var location: String
    var title: String
    var labels: [String]
    var specialInstruction: String
    var music: MusicInfo
    var upvotes: Int
    var downvotes: Int
    var imageUrl: String
    var createdAt: Date?
}

struct MusicInfo: Codable {
    var title: String
    var artist: String
}
