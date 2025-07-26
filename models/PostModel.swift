import Foundation
import FirebaseFirestore
import FirebaseFirestore
import CoreLocation

struct PostModel: Identifiable, Codable {
    var id: String
    var userId: String
    var imageUrl: String
    var specialInstruction: String
    var labels: [String]
    var timestamp: Timestamp
    var location: GeoPoint
    
    func toDict() -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "imageUrl": imageUrl,
            "specialInstruction": specialInstruction,
            "labels": labels,
            "timestamp": timestamp,
            "location": location
        ]
    }

    static func fromDict(_ dict: [String: Any]) -> PostModel? {
        guard
            let id = dict["id"] as? String,
            let userId = dict["userId"] as? String,
            let imageUrl = dict["imageUrl"] as? String,
            let specialInstruction = dict["specialInstruction"] as? String,
            let labels = dict["labels"] as? [String],
            let timestamp = dict["timestamp"] as? Timestamp,
            let location = dict["location"] as? GeoPoint
        else {
            return nil
        }

        return PostModel(
            id: id,
            userId: userId,
            imageUrl: imageUrl,
            specialInstruction: specialInstruction,
            labels: labels,
            timestamp: timestamp,
            location: location
        )
    }
}
