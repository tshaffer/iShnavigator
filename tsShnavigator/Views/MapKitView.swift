import SwiftUI
import MapKit

// MKTileOverlay doesn't set a User-Agent by default; OpenTopoMap blocks requests without one.
private class UserAgentTileOverlay: MKTileOverlay {
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let url = url(forTilePath: path)
        var request = URLRequest(url: url)
        request.setValue("tsShnavigator/1.0 (iOS; com.tedshaffer.tsShnavigator)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, error in
            result(data, error)
        }.resume()
    }
}

struct MapKitView: UIViewRepresentable {
    let route: Route?
    let recordedCoordinates: [CLLocationCoordinate2D]
    let tileStyle: MapTileStyle
    let initialRegion: MKCoordinateRegion?
    let recenterID: UUID  // change this value to trigger a recenter

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true

        let trackingButton = MKUserTrackingButton(mapView: mapView)
        trackingButton.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(trackingButton)
        NSLayoutConstraint.activate([
            trackingButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -12),
            trackingButton.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coord = context.coordinator

        if !coord.hasSetInitialRegion {
            if let region = initialRegion {
                mapView.setRegion(region, animated: false)
            } else {
                mapView.userTrackingMode = .follow
            }
            coord.hasSetInitialRegion = true
        }

        if coord.lastRecenterID != recenterID {
            coord.lastRecenterID = recenterID
            if let region = initialRegion {
                mapView.setRegion(region, animated: true)
            } else {
                mapView.userTrackingMode = .follow
            }
        }

        if coord.currentTileStyle != tileStyle {
            coord.currentTileStyle = tileStyle
            applyTileStyle(tileStyle, to: mapView, coordinator: coord)
        }

        // Update route polyline
        let routeCoords = route?.coordinates ?? []
        if coord.routeCoordCount != routeCoords.count {
            coord.routeCoordCount = routeCoords.count
            if let existing = coord.routePolyline {
                mapView.removeOverlay(existing)
            }
            if !routeCoords.isEmpty {
                let polyline = MKPolyline(coordinates: routeCoords, count: routeCoords.count)
                coord.routePolyline = polyline
                // .aboveLabels so polylines always render on top of custom tile overlays
                mapView.addOverlay(polyline, level: .aboveLabels)
            } else {
                coord.routePolyline = nil
            }
        }

        // Update recording polyline
        if coord.recordingCoordCount != recordedCoordinates.count {
            coord.recordingCoordCount = recordedCoordinates.count
            if let existing = coord.recordingPolyline {
                mapView.removeOverlay(existing)
            }
            if !recordedCoordinates.isEmpty {
                let polyline = MKPolyline(coordinates: recordedCoordinates, count: recordedCoordinates.count)
                coord.recordingPolyline = polyline
                mapView.addOverlay(polyline, level: .aboveLabels)
            } else {
                coord.recordingPolyline = nil
            }
        }
    }

    private func applyTileStyle(_ style: MapTileStyle, to mapView: MKMapView, coordinator: Coordinator) {
        if let existing = coordinator.tileOverlay {
            mapView.removeOverlay(existing)
            coordinator.tileOverlay = nil
        }

        switch style {
        case .standard:
            mapView.mapType = .standard
        case .hybrid:
            mapView.mapType = .hybrid
        case .satellite:
            mapView.mapType = .satellite
        case .openTopoMap, .thunderforest:
            mapView.mapType = .mutedStandard
            if let urlTemplate = style.tileURLTemplate {
                let overlay = UserAgentTileOverlay(urlTemplate: urlTemplate)
                overlay.canReplaceMapContent = true
                coordinator.tileOverlay = overlay
                mapView.addOverlay(overlay, level: .aboveLabels)
            }
        }

        // Re-add polylines above the tile overlay at the same .aboveLabels level
        if let route = coordinator.routePolyline {
            mapView.removeOverlay(route)
            mapView.addOverlay(route, level: .aboveLabels)
        }
        if let recording = coordinator.recordingPolyline {
            mapView.removeOverlay(recording)
            mapView.addOverlay(recording, level: .aboveLabels)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var hasSetInitialRegion = false
        var lastRecenterID: UUID = UUID()
        var currentTileStyle: MapTileStyle?
        var tileOverlay: MKTileOverlay?
        var routePolyline: MKPolyline?
        var recordingPolyline: MKPolyline?
        var routeCoordCount = -1
        var recordingCoordCount = -1

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.strokeColor = (polyline === routePolyline) ? .systemOrange : .systemGreen
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
