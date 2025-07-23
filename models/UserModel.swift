import Foundation
import FirebaseFirestore

struct UserModel: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var fullName: String
    var email: String?
    var phoneNumber: String?
    var profileImageUrl: String?
    var joinDate: Date?
    var visitedLocations: [String] // Array of location IDs
}
