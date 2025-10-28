//
//  ContentView.swift
//  NavigationMap
//
//  Created by BizMagnets on 27/10/25.
//

import SwiftUICore
import SwiftUI


struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Direction", systemImage: "map.circle") {
               DirectionMapView()
            }
            Tab("Favorite", systemImage: "heart.circle") {
               FavoritesView()
            }
        }
        
    }
}

#Preview {
    ContentView()
}
