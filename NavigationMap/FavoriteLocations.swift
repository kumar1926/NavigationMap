//
//  FavoriteLocations.swift
//  NavigationMap
//
//  Created by BizMagnets on 28/10/25.
//

import Foundation

class FavoriteLocations: ObservableObject {
    @Published var locations: [Location] = []
}
struct Location: Identifiable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
}
