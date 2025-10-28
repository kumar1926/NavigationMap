//
//  DirectionMapView.swift
//  NavigationMap
//
//  Created by BizMagnets on 28/10/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct DirectionMapView: View {
    let manager = CLLocationManager()
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var route:MKRoute?
    @State private var destinationSelected: Bool = false
    @State private var showRouteErrorToast = false
    
    var body: some View {
        
        MapReader { proxy in
            Map(position: $cameraPosition) {
                
                UserAnnotation()
                
                if let coordinate = destinationCoordinate {
                    Annotation("Destination",coordinate: coordinate,anchor: .bottom){
                        Image(systemName: "mappin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .padding(7)
                            .background(.red.gradient, in: .circle)
                        
                    }
                    
                    
                }
                if let route = route {
                    MapPolyline(route)
                        .stroke(Color.yellow, lineWidth: 4)
                }
                
            }
            .onTapGesture { position in
                
                if let coordinate = proxy.convert(position, from: .local) {
                    destinationCoordinate = coordinate
                    getDirection(coordinate: coordinate)
                    destinationSelected = true
                    
                }
                
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .onAppear {
                manager.requestWhenInUseAuthorization()
                manager.startUpdatingLocation()
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .overlay(
                Group {
                    if showRouteErrorToast {
                        Text("Route not found")
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showRouteErrorToast = false
                                    }
                                }
                            }
                    }
                }
                .animation(.easeInOut, value: showRouteErrorToast)
                , alignment: .bottom
            )
        }
    }
    func getUsuerLocation() async -> CLLocationCoordinate2D?{
        let updates = CLLocationUpdate.liveUpdates()
        do {
            let update = try await updates.first{ $0.location?.coordinate != nil}
            return update?.location?.coordinate
            
        }catch{
            return nil
        }
    }
    func getDirection(coordinate: CLLocationCoordinate2D) {
        Task {
            guard let userLocation = try? await getUsuerLocation() else { return }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            request.transportType = .walking
            do {
                let direction = try await MKDirections(request: request).calculate()
                route = direction.routes.first
                if route == nil {
                    showRouteErrorToast = true
                }
            } catch {
                route = nil
                showRouteErrorToast = true
            }
        }
    }
}

#Preview {
    DirectionMapView()
}
