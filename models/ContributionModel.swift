//
//  ContributionModel.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/21/25.
//


// ContributionModel.swift

import Foundation
import FirebaseFirestore

struct ContributionModel: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var username: String
    var music: MusicInfo?
    var instruction: String?
    var labels: [String]
    var timestamp: Date?
}
