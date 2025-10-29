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
    @State private var primaryRoute: MKRoute? // For the best route
    @State private var alternativeRoutes: [MKRoute] = []
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
                ForEach(alternativeRoutes, id: \.self) { route in
                    MapPolyline(route)
                        .stroke(Color.yellow.opacity(0.45), lineWidth: 5)
                    if let midPoint = getMidPoint(for: route){
                        Annotation("",coordinate: midPoint){
                            RouteTimeAnnotation(time: format(timeInterval: route.expectedTravelTime), isPrimary: false)
                        }
                    }
                }
                
                
                if let route = primaryRoute {
                    MapPolyline(route)
                        .stroke(Color.blue, lineWidth: 5)
                    if let midPoint = getMidPoint(for: route){
                        Annotation("",coordinate: midPoint){
                            RouteTimeAnnotation(time: format(timeInterval: route.expectedTravelTime), isPrimary: true)
                        }
                    }
                    
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
            guard let userLocation = try? await getUsuerLocation() else {
                showRouteErrorToast = true
                return
            }
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            request.transportType = .automobile
            request.requestsAlternateRoutes = true
            
            do {
                let direction = try await MKDirections(request: request).calculate()
                print("routes count:\(direction.routes.count)")
                if let firstRoute = direction.routes.first {
                    primaryRoute = firstRoute
                    alternativeRoutes = Array(direction.routes.dropFirst())
                    showRouteErrorToast = false
                } else {
                    primaryRoute = nil
                    alternativeRoutes = []
                    showRouteErrorToast = true
                }
            } catch {
                primaryRoute = nil
                alternativeRoutes = []
                showRouteErrorToast = true
            }
        }
    }
    func getMidPoint(for route: MKRoute) -> CLLocationCoordinate2D? {
        guard route.polyline.pointCount > 0 else {
            return nil
        }
        
        let point = route.polyline.points()
        let midIndex = route.polyline.pointCount / 2
        let mappedPoint = point[midIndex]
        return mappedPoint.coordinate
        
    }
    func format(timeInterval: TimeInterval) -> String {
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.allowedUnits = [.hour, .minute]
            
            if timeInterval < 60 {
                 return "0m"
            }
            
            return formatter.string(from: timeInterval) ?? ""
        }
}

#Preview {
    DirectionMapView()
}

struct RouteTimeAnnotation:View {
    var time:String
    var isPrimary:Bool
    var body: some View {
        Text(time)
            .font(.caption)
            .bold()
            .padding(isPrimary ? 7:6)
            .foregroundStyle(isPrimary ? Color.white:Color.yellow.opacity(0.8))
            .background(isPrimary ? Color.blue:Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .shadow(radius: isPrimary ? 3:1)
            .overlay{
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isPrimary ? Color.clear : Color.yellow.opacity(0.8), lineWidth: 1)
            }
        
    }
}
