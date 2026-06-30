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

// Annotation that marks the user's location for the heading cone view.
final class HeadingAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    init(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

// Draws a blue wedge pointing in the current heading direction.
final class HeadingAnnotationView: MKAnnotationView {
    static let reuseID = "HeadingCone"

    private static let coneImage: UIImage = {
        let size = CGSize(width: 60, height: 60)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let ctx = UIGraphicsGetCurrentContext()!
            let cx = size.width / 2, cy = size.height / 2
            let radius: CGFloat = 26
            let half: CGFloat = 25 * .pi / 180  // ±25° half-angle
            ctx.setFillColor(UIColor.systemBlue.withAlphaComponent(0.5).cgColor)
            ctx.move(to: CGPoint(x: cx, y: cy))
            // Arc centered at cx,cy, pointing up (−π/2), spanning ±half
            ctx.addArc(center: CGPoint(x: cx, y: cy),
                       radius: radius,
                       startAngle: -.pi / 2 - half,
                       endAngle: -.pi / 2 + half,
                       clockwise: false)
            ctx.closePath()
            ctx.fillPath()
        }
    }()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        isEnabled = false
        image = HeadingAnnotationView.coneImage
        centerOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - MapKitView

struct MapKitView: UIViewRepresentable {
    let route: Route?
    let recordedCoordinates: [CLLocationCoordinate2D]
    let tileStyle: MapTileStyle
    let initialRegion: MKCoordinateRegion?
    let recenterID: UUID
    let userHeading: Double?  // degrees true north; nil = no heading data

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

        // Route polyline
        let routeCoords = route?.coordinates ?? []
        if coord.routeCoordCount != routeCoords.count {
            coord.routeCoordCount = routeCoords.count
            if let existing = coord.routePolyline { mapView.removeOverlay(existing) }
            if !routeCoords.isEmpty {
                let polyline = MKPolyline(coordinates: routeCoords, count: routeCoords.count)
                coord.routePolyline = polyline
                mapView.addOverlay(polyline, level: .aboveLabels)
            } else {
                coord.routePolyline = nil
            }
        }

        // Recording polyline
        if coord.recordingCoordCount != recordedCoordinates.count {
            coord.recordingCoordCount = recordedCoordinates.count
            if let existing = coord.recordingPolyline { mapView.removeOverlay(existing) }
            if !recordedCoordinates.isEmpty {
                let polyline = MKPolyline(coordinates: recordedCoordinates, count: recordedCoordinates.count)
                coord.recordingPolyline = polyline
                mapView.addOverlay(polyline, level: .aboveLabels)
            } else {
                coord.recordingPolyline = nil
            }
        }

        // Heading cone annotation
        updateHeadingAnnotation(mapView: mapView, coordinator: coord)
    }

    private func updateHeadingAnnotation(mapView: MKMapView, coordinator: Coordinator) {
        let userCoord = mapView.userLocation.coordinate
        let hasValidLocation = CLLocationCoordinate2DIsValid(userCoord) && userCoord.latitude != 0

        guard let heading = userHeading, hasValidLocation else {
            if let ann = coordinator.headingAnnotation {
                mapView.removeAnnotation(ann)
                coordinator.headingAnnotation = nil
            }
            return
        }

        if coordinator.headingAnnotation == nil {
            let ann = HeadingAnnotation(userCoord)
            coordinator.headingAnnotation = ann
            mapView.addAnnotation(ann)
        } else {
            coordinator.headingAnnotation?.coordinate = userCoord
        }

        // Rotate the cone view to match heading (adjusted for map camera rotation)
        if let view = mapView.view(for: coordinator.headingAnnotation!) as? HeadingAnnotationView {
            let mapHeading = mapView.camera.heading
            let angle = (heading - mapHeading) * .pi / 180
            view.transform = CGAffineTransform(rotationAngle: angle)
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
        var headingAnnotation: HeadingAnnotation?

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

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is HeadingAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: HeadingAnnotationView.reuseID)
                as? HeadingAnnotationView
                ?? HeadingAnnotationView(annotation: annotation, reuseIdentifier: HeadingAnnotationView.reuseID)
            view.annotation = annotation
            return view
        }
    }
}
