//
//  FavoritesView.swift
//  NavigationMap
//
//  Created by BizMagnets on 28/10/25.
//

import SwiftUI
import MapKit
import CoreLocation
import GoogleMaps

struct FavoritesView: View {
    let manager = CLLocationManager()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @StateObject private var LocationList = FavoriteLocations()
    @State private var route:MKRoute?
    var body: some View {
        MapReader{ proxy in
            Map(position: $cameraPosition) {
                Group {
                    UserAnnotation()
                    
                    ForEach(LocationList.locations, id: \.id) { location in
                        Annotation("\(location.name)", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), anchor: .bottom) {
                            Image(systemName: "heart.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .padding(7)
                                .background(Color.red.gradient, in: .circle)
                                .contextMenu {
                                    Button("Get Directions", systemImage: "arrow.turn.down.right") {
                                        getLocation(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                                    }
                                }
                        }
                    }
                    
                    if let route = route {
                        MapPolyline(route)
                            .stroke(.blue, lineWidth: 5)
                    }
                }
            }
            .tint(.red)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .onTapGesture{ position in
                if let coordinate = proxy.convert(position, from: .local){
                    let loction = Location(name: "favorite", latitude: coordinate.latitude, longitude: coordinate.longitude)
                    LocationList.locations.append(loction)
                }
                
            }
            .onAppear(){
                manager.requestWhenInUseAuthorization()
            }
        }
    }
    func getUserLocation() async ->CLLocationCoordinate2D?{
        let updates = CLLocationUpdate.liveUpdates()
        do{
            let update = try await updates.first{ $0.location?.coordinate != nil }
            return update?.location?.coordinate
        }catch{
            return nil
        }
    }
    func getLocation(coordinate:CLLocationCoordinate2D){
        Task{
            guard let userLocation = try? await getUserLocation() else {
                return
            }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            request.transportType = .walking
            do{
                let direction = try await MKDirections(request: request).calculate()
                route = direction.routes.first
            }catch{
                route = nil
            }
        }
        
    }
}

#Preview {
    FavoritesView()
}
