//
//  NavigatingUserAnnotation.swift
//  NavigationMap
//
//  Created by BizMagnets on 04/11/25.
//

import SwiftUI
import CoreLocation

struct NavigatingUserAnnotation: View {
    let isNavigating: Bool
    let heading: CLLocationDirection?

    var body: some View {
        if isNavigating {
            Image(systemName: "location.north.line.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(heading ?? 0))
                .background(Color.white, in: Circle())
                .shadow(radius: 5)
        } else {
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(radius: 5)
        }
    }
}

#Preview {
    NavigatingUserAnnotation(isNavigating: true, heading: nil)
}
