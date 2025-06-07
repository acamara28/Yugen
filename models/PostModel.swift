import Foundation
import FirebaseFirestore
import FirebaseFirestore

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var imageUrl: String
    var title: String
    var labels: [String]
    var musicTitle: String
    var musicArtist: String
    var comment: String
    var timestamp: Date
    var latitude: Double       // ✅ now included
    var longitude: Double      // ✅ now included
}
