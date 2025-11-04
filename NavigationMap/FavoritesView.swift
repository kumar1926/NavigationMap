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
    @State private var destinationName: String = "Destination"
    @State private var showRouteErrorToast = false
    @State private var primaryRoute: MKRoute?
    @State private var alternativeRoutes: [MKRoute] = []
    @State private var isNavigating: Bool = false
    @State private var showNavigationSteps: Bool = false
    @State private var currentStepIndex: Int = 0
    @State private var currentUserLocation: CLLocationCoordinate2D?
    @State private var userHeading: CLLocationDirection? = nil
    @StateObject private var locationDelegate = LocationUpdateDelegate()
    @State private var didAddDefaultLocations = false
    var body: some View {
        ZStack{
            MapReader{ proxy in
                Map(position: $cameraPosition) {
                    Group {
                        if let currentUserLocation = currentUserLocation{
                            Annotation("me",coordinate: currentUserLocation){
                                NavigatingUserAnnotation(isNavigating: isNavigating, heading: userHeading)
                            }
                        }
                        
                        ForEach(LocationList.locations, id: \.id) { location in
                            Annotation("\(location.name)", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), anchor: .bottom) {
                                Button{
                                    print("tap on \(location.name)")
                                }label:{
                                    Image(systemName: "heart.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .padding(7)
                                        .background(Color.red.gradient, in: .circle)
                                        .contextMenu {
                                            Button("Get Routes", systemImage: "arrow.turn.down.right") {
                                                getDirection(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                                            }
                                            Button("Get Directions", systemImage: "arrow.turn.down.right") {
                                                getDirection(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                                                showNavigationSteps = true
                                            }
                                            
                                        }
                                }
                            }
                        }
                        
                        ForEach(alternativeRoutes, id: \.self) { route in
                            MapPolyline(route)
                                .stroke(Color.yellow.opacity(0.45), lineWidth: 5)
                            
                            if let midPoint = getMidPoint(for: route) {
                                Annotation("", coordinate: midPoint) {
                                    RouteTimeAnnotation(
                                        time: format(timeInterval: route.expectedTravelTime),
                                        isPrimary: false
                                    )
                                    
                                }
                            }
                        }

                        if let route = primaryRoute {
                            MapPolyline(route)
                                .stroke(Color.blue, lineWidth: 5)
                            
                            if let midPoint = getMidPoint(for: route) {
                                Annotation("", coordinate: midPoint) {
                                    RouteTimeAnnotation(
                                        time: format(timeInterval: route.expectedTravelTime),
                                        isPrimary: true
                                    )
                                }
                            }
                        }
                    }
                }
                .animation(.easeInOut, value: isNavigating)
                .tint(.red)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapPitchToggle()
                    MapScaleView()
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        Task {
                            let locationName = await getPlacemarkName(for: coordinate)
                            let location = Location(name: locationName, latitude: coordinate.latitude, longitude: coordinate.longitude)
                            LocationList.locations.append(location)
                        }
                        showNavigationSteps = false
                    }
                }
                .onAppear(){
                    manager.requestWhenInUseAuthorization()
                    manager.startUpdatingLocation()
                    
                    if !didAddDefaultLocations {
                        // Default Chennai Locations
                        let defaultChennaiLocations = [
                            Location(name: "Marina Beach", latitude: 13.0494, longitude: 80.2824),
                            Location(name: "Chennai Central", latitude: 13.0827, longitude: 80.2707),
                            Location(name: "Guindy National Park", latitude: 13.0050, longitude: 80.2342),
                            Location(name: "Phoenix MarketCity", latitude: 12.9910, longitude: 80.2167),
                            Location(name: "T Nagar", latitude: 13.0418, longitude: 80.2337)
                        ]
                        LocationList.locations.append(contentsOf: defaultChennaiLocations)
                        didAddDefaultLocations = true
                    }

                    locationDelegate.onLocationUpdate = { location in
                        currentUserLocation = location.coordinate
                        if isNavigating {
                            updateNavigationStep(userLocation: location.coordinate)
                        }
                    }
                    locationDelegate.onHeadingUpdate = { heading in
                        userHeading = heading
                    }
                }
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
                .sheet(isPresented: $showNavigationSteps) {
                    NavigationStepsView(
                        route: primaryRoute,
                        destinationName: destinationName,
                        onStartNavigation: {
                            showNavigationSteps = false
                            startNavigation()
                        }
                    )
                }
            }
            if isNavigating, let route = primaryRoute, currentStepIndex < route.steps.count {
                VStack {
                    NavigationInstructionView(
                        step: route.steps[currentStepIndex],
                        userLocation: currentUserLocation,
                        onEndNavigation: {
                            endNavigation()
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
            }
        }
        
    }
    func startNavigation() {
        guard let route = primaryRoute else { return }
        isNavigating = true
        currentStepIndex = 0
        
        // Update camera to follow user
        if let userLocation = currentUserLocation {
            withAnimation {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: userLocation,
                    distance: 500,
                    heading: 0,
                    pitch: 60
                ))
            }
        }
    }
    func endNavigation() {
        withAnimation {
            isNavigating = false
            currentStepIndex = 0
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
    func getDirection(coordinate: CLLocationCoordinate2D) {
        Task {
            guard let userLocation = try? await getUserLocation() else {
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
    func getPlacemarkName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = placemark.name
                let street = placemark.thoroughfare
                let locality = placemark.locality
                
                if let name = name, name.lowercased() != street?.lowercased() {
                    return name
                } else if let street = street {
                    return street
                } else if let locality = locality {
                    return locality
                } else {
                    return "Dropped Pin"
                }
            } else {
                return "Unknown Location"
            }
        } catch {
            print("Reverse geocoding error: \(error.localizedDescription)")
            return "Location (\(String(format: "%.2f", coordinate.latitude)), \(String(format: "%.2f", coordinate.longitude)))"
        }
    }
    func updateNavigationStep(userLocation: CLLocationCoordinate2D) {
        guard let route = primaryRoute, currentStepIndex < route.steps.count else { return }
        
        let currentStep = route.steps[currentStepIndex]
        
        // Get the coordinate at the end of the current step
        let stepEndCoordinate = getStepEndCoordinate(step: currentStep)
        
        // Calculate distance from user to step end point
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let stepEndLocation = CLLocation(latitude: stepEndCoordinate.latitude, longitude: stepEndCoordinate.longitude)
        let distanceToStepEnd = userCLLocation.distance(from: stepEndLocation)
        
        // If user is within 50 meters of step end, move to next step
        if distanceToStepEnd < 50 && currentStepIndex < route.steps.count - 1 {
            withAnimation {
                currentStepIndex += 1
            }
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        
        // Update camera to follow user
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: userLocation,
                distance: 500,
                heading: 0,
                pitch: 60
            ))
        }
    }
}

#Preview {
    FavoritesView()
}
