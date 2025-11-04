//
//  NavigationStepsView.swift
//  NavigationMap
//
//  Created by BizMagnets on 04/11/25.
//

import SwiftUI
import MapKit

struct NavigationStepsView: View {
    let route: MKRoute?
    let destinationName: String
    let onStartNavigation: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: onStartNavigation) {
                        HStack {
                            Spacer()
                            Label("Start Navigation", systemImage: "location.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                    .foregroundColor(.white)
                }
                
                Section(header: Text("Route Summary")) {
                    HStack {
                        Image(systemName: "clock")
                        Text("Time: \(DirectionMapView().format(timeInterval: route?.expectedTravelTime ?? 0))")
                    }
                    HStack {
                        Image(systemName: "ruler")
                        Text("Distance: \(DirectionMapView().format(distance: route?.distance ?? 0))")
                    }
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Destination: **\(destinationName)**")
                    }
                }

                if let steps = route?.steps, steps.count > 0 {
                    Section(header: Text("Turn-by-Turn Directions")) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            if !step.instructions.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: getManeuverIcon(for: step))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.instructions)
                                            .font(.body)
                                        Text(DirectionMapView().format(distance: step.distance))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    Text("No detailed steps available for this route.")
                }
            }
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func getManeuverIcon(for step: MKRoute.Step) -> String {
        let instruction = step.instructions.lowercased()
        
        if instruction.contains("turn right") || instruction.contains("right onto") {
            return "arrow.turn.up.right"
        } else if instruction.contains("turn left") || instruction.contains("left onto") {
            return "arrow.turn.up.left"
        } else if instruction.contains("slight right") {
            return "arrow.up.right"
        } else if instruction.contains("slight left") {
            return "arrow.up.left"
        } else if instruction.contains("arrive") || instruction.contains("destination") {
            return "mappin.circle.fill"
        } else {
            return "arrow.up"
        }
    }
}

#Preview {
    NavigationStepsView(route: nil, destinationName: "", onStartNavigation: {})
}
