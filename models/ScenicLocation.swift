//
//  ScenicLocation.swift
//  SceneIt
//
//  Created by Alpha  Camara on 7/26/25.
//


import Foundation
import FirebaseFirestore

struct ScenicLocation: Identifiable, Equatable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var posts: [PostModel] = []

    static func == (lhs: ScenicLocation, rhs: ScenicLocation) -> Bool {
        lhs.id == rhs.id
    }
}
