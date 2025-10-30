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
    @State private var destinationName: String = "Destination"
    @State private var primaryRoute: MKRoute?
    @State private var alternativeRoutes: [MKRoute] = []
    @State private var destinationSelected: Bool = false
    @State private var showRouteErrorToast = false
    
    @State private var showNavigationSteps: Bool = false
    
    @State private var isNavigating: Bool = false
    @State private var currentStepIndex: Int = 0
    @State private var currentUserLocation: CLLocationCoordinate2D?
    @StateObject private var locationDelegate = LocationUpdateDelegate()
    
    var body: some View {
        
        ZStack {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    
                    UserAnnotation()
                    
                    if let coordinate = destinationCoordinate {

                        Annotation(destinationName, coordinate: coordinate, anchor: .bottom){
                            VStack(spacing: 5) {
                                Button {
                                    withAnimation {
                                        showNavigationSteps.toggle()
                                    }
                                } label: {
                                    Image(systemName: "mappin")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .padding(7)
                                        .background(.red.gradient, in: .circle)
                                }
                                if let route = primaryRoute {
                                    Text("\(format(distance: route.distance))")
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.white.opacity(0.8))
                                        .cornerRadius(5)
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
                                .onTapGesture {
                                    selectRoute(route)
                                }
                                
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
                
                .onTapGesture { position in
                    // Existing logic for setting the destination on a tap
                    if let coordinate = proxy.convert(position, from: .local) {
                        destinationCoordinate = coordinate
                        destinationSelected = true
                        getDirection(coordinate: coordinate)
                        
                        Task {
                            await getPlacemarkName(for: coordinate)
                        }
                        showNavigationSteps = false
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
                    
                    // NEW: Set up location tracking
                    locationDelegate.onLocationUpdate = { location in
                        currentUserLocation = location.coordinate
                        if isNavigating {
                            updateNavigationStep(userLocation: location.coordinate)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                // Navigation steps are shown here as a sheet/overlay
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
                // Overlay for route error toast (unchanged)
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
        .animation(.easeInOut, value: isNavigating)
    }
    
    func selectRoute(_ selectedRoute: MKRoute) {
        if let index = alternativeRoutes.firstIndex(where: { $0.polyline == selectedRoute.polyline }) {
            if let currentPrimary = primaryRoute {
                alternativeRoutes[index] = currentPrimary
            }

            primaryRoute = selectedRoute

            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    
    func format(distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
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
    
    func getPlacemarkName(for coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = placemark.name
                let street = placemark.thoroughfare
                let locality = placemark.locality
                
                if let name = name, name.lowercased() != street?.lowercased() {
                    destinationName = name
                } else if let street = street {
                    destinationName = street
                } else if let locality = locality {
                    destinationName = locality
                } else {
                    destinationName = "Dropped Pin"
                }
            } else {
                destinationName = "Unknown Location"
            }
        } catch {
            print("Reverse geocoding error: \(error.localizedDescription)")
            destinationName = "Location (\(String(format: "%.2f", coordinate.latitude)), \(String(format: "%.2f", coordinate.longitude)))"
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
    
    func getStepEndCoordinate(step: MKRoute.Step) -> CLLocationCoordinate2D {
        let polyline = step.polyline
        guard polyline.pointCount > 0 else {
            return CLLocationCoordinate2D()
        }
        
        let points = polyline.points()
        let lastPoint = points[polyline.pointCount - 1]
        return lastPoint.coordinate
    }
}

class LocationUpdateDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    var onLocationUpdate: ((CLLocation) -> Void)?
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocationUpdate?(location)
    }
}

struct NavigationInstructionView: View {
    let step: MKRoute.Step
    let userLocation: CLLocationCoordinate2D?
    let onEndNavigation: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: getManeuverIcon())
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                if let distance = distanceToStep() {
                    Text(formatDistance(distance))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Text(step.instructions.isEmpty ? "Continue" : step.instructions)
                    .font(.body)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onEndNavigation) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
    }
    
    private func getManeuverIcon() -> String {
        let instruction = step.instructions.lowercased()
        
        if instruction.contains("turn right") || instruction.contains("right onto") {
            return "arrow.turn.up.right"
        } else if instruction.contains("turn left") || instruction.contains("left onto") {
            return "arrow.turn.up.left"
        } else if instruction.contains("slight right") {
            return "arrow.up.right"
        } else if instruction.contains("slight left") {
            return "arrow.up.left"
        } else if instruction.contains("sharp right") {
            return "arrow.turn.right.up"
        } else if instruction.contains("sharp left") {
            return "arrow.turn.left.up"
        } else if instruction.contains("u-turn") {
            return "arrow.uturn.forward"
        } else if instruction.contains("merge") {
            return "arrow.triangle.merge"
        } else if instruction.contains("roundabout") {
            return "arrow.triangle.2.circlepath"
        } else if instruction.contains("arrive") || instruction.contains("destination") {
            return "mappin.circle.fill"
        } else {
            return "arrow.up"
        }
    }
    
    private func distanceToStep() -> CLLocationDistance? {
        guard let userLocation = userLocation else { return step.distance }
        
        let polyline = step.polyline
        guard polyline.pointCount > 0 else { return step.distance }
        
        let points = polyline.points()
    
        let stepEndCoordinate = points[polyline.pointCount - 1].coordinate
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let stepEndLocation = CLLocation(latitude: stepEndCoordinate.latitude, longitude: stepEndCoordinate.longitude)

        return userCLLocation.distance(from: stepEndLocation)
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {

        if distance < 1000 {

            let roundedDistance = (distance / 10).rounded() * 10
            return "\(Int(roundedDistance)) m"
        } else {

            let km = distance / 1000
            return String(format: "%.1f km", km)
        }
    }
}

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
