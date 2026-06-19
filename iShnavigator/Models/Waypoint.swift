import Foundation
import CoreLocation

struct Waypoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let timestamp: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
