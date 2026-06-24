import SwiftUI
import MapKit

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

        // User location tracking button
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

        // Initial region — set once
        if !coord.hasSetInitialRegion {
            if let region = initialRegion {
                mapView.setRegion(region, animated: false)
            } else {
                mapView.userTrackingMode = .follow
            }
            coord.hasSetInitialRegion = true
        }

        // Recenter when triggered
        if coord.lastRecenterID != recenterID {
            coord.lastRecenterID = recenterID
            if let region = initialRegion {
                mapView.setRegion(region, animated: true)
            } else {
                mapView.userTrackingMode = .follow
            }
        }

        // Update base map style / tile overlay
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
                mapView.addOverlay(polyline, level: .aboveRoads)
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
                mapView.addOverlay(polyline, level: .aboveRoads)
            } else {
                coord.recordingPolyline = nil
            }
        }
    }

    private func applyTileStyle(_ style: MapTileStyle, to mapView: MKMapView, coordinator: Coordinator) {
        // Remove existing tile overlay
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
                let overlay = MKTileOverlay(urlTemplate: urlTemplate)
                overlay.canReplaceMapContent = true
                coordinator.tileOverlay = overlay
                mapView.addOverlay(overlay, level: .aboveLabels)
            }
        }

        // Re-add route/recording polylines so they render above the new tile overlay
        if let route = coordinator.routePolyline {
            mapView.removeOverlay(route)
            mapView.addOverlay(route, level: .aboveRoads)
        }
        if let recording = coordinator.recordingPolyline {
            mapView.removeOverlay(recording)
            mapView.addOverlay(recording, level: .aboveRoads)
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
