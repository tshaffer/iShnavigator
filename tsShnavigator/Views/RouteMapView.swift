import SwiftUI
import MapKit

struct HeadingAnnotation: View {
    let headingDegrees: Double

    var body: some View {
        ZStack {
            // Heading cone behind the dot
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue.opacity(0.8))
                .offset(y: -18)
                .rotationEffect(.degrees(headingDegrees))

            // Blue dot
            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(.blue).padding(3))
                .shadow(radius: 2)
        }
    }
}

struct RouteMapView: View {
    let route: Route
    let locationManager: LocationManager

    @State private var position: MapCameraPosition

    init(route: Route, locationManager: LocationManager) {
        self.route = route
        self.locationManager = locationManager
        if let region = route.region {
            _position = State(initialValue: .region(region))
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    var body: some View {
        Map(position: $position) {
            MapPolyline(coordinates: route.coordinates)
                .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

            if let location = locationManager.currentLocation {
                let coord = location.coordinate
                if let heading = locationManager.heading, heading.headingAccuracy >= 0 {
                    Annotation("", coordinate: coord) {
                        HeadingAnnotation(headingDegrees: heading.trueHeading)
                    }
                } else {
                    Annotation("", coordinate: coord) {
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().fill(.blue).padding(3))
                            .shadow(radius: 2)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    recenterOnRoute()
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                }
            }
        }
        .onAppear {
            locationManager.requestPermissionAndStart()
        }
    }

    private func recenterOnRoute() {
        guard let region = route.region else { return }
        withAnimation {
            position = .region(region)
        }
    }
}
