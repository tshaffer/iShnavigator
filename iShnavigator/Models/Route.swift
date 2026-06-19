import Foundation
import MapKit

struct Route: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let waypoints: [Waypoint]
    let importedAt: Date

    init(id: UUID = UUID(), name: String, waypoints: [Waypoint], importedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.waypoints = waypoints
        self.importedAt = importedAt
    }

    var coordinates: [CLLocationCoordinate2D] {
        waypoints.map(\.coordinate)
    }

    var totalDistanceMeters: Double {
        guard waypoints.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<waypoints.count {
            let a = CLLocation(latitude: waypoints[i-1].latitude, longitude: waypoints[i-1].longitude)
            let b = CLLocation(latitude: waypoints[i].latitude, longitude: waypoints[i].longitude)
            total += a.distance(from: b)
        }
        return total
    }

    var region: MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.3, longitudeDelta: (maxLon - minLon) * 1.3)
        return MKCoordinateRegion(center: center, span: span)
    }
}
