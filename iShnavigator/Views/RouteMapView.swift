import SwiftUI
import MapKit

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
            UserAnnotation()
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
