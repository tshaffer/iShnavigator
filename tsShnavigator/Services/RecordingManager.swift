import Foundation
import CoreLocation
import Observation

enum RecordingState {
    case idle
    case recording
    case finished
}

@Observable
final class RecordingManager {
    var state: RecordingState = .idle
    var recordedLocations: [CLLocation] = []
    var elapsedSeconds: Int = 0

    private var startTime: Date?
    private var timer: Timer?
    private weak var locationManager: LocationManager?

    var recordedCoordinates: [CLLocationCoordinate2D] {
        recordedLocations.map(\.coordinate)
    }

    var elapsedDistance: Double {
        guard recordedLocations.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<recordedLocations.count {
            total += recordedLocations[i].distance(from: recordedLocations[i-1])
        }
        return total
    }

    func start(locationManager: LocationManager) {
        self.locationManager = locationManager
        recordedLocations = []
        elapsedSeconds = 0
        startTime = Date()
        state = .recording
        locationManager.enableBackgroundTracking()
        // Use a tolerance so the timer coalesces well; elapsed time is derived from
        // wall-clock start time so it stays accurate across background/foreground cycles.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
        // Allows the timer to fire while the run loop is in tracking mode (e.g. scrolling)
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .finished
        locationManager?.disableBackgroundTracking()
        locationManager = nil
    }

    func discard() {
        timer?.invalidate()
        timer = nil
        locationManager?.disableBackgroundTracking()
        locationManager = nil
        recordedLocations = []
        elapsedSeconds = 0
        startTime = nil
        state = .idle
    }

    private static let normalAccuracyThreshold: Double = 50
    private static let fallbackAccuracyThreshold: Double = 150
    private static let fallbackInterval: TimeInterval = 10

    func addLocation(_ location: CLLocation) {
        guard state == .recording else { return }
        guard location.horizontalAccuracy >= 0 else { return }

        let acceptNormal = location.horizontalAccuracy < Self.normalAccuracyThreshold
        let timeSinceLast = recordedLocations.last.map { location.timestamp.timeIntervalSince($0.timestamp) } ?? .infinity
        let acceptFallback = timeSinceLast >= Self.fallbackInterval
                          && location.horizontalAccuracy < Self.fallbackAccuracyThreshold

        guard acceptNormal || acceptFallback else { return }
        recordedLocations.append(location)
    }

    func toRoute(name: String) -> Route {
        let waypoints = recordedLocations.map { loc in
            Waypoint(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                elevation: loc.verticalAccuracy >= 0 ? loc.altitude : nil,
                timestamp: loc.timestamp
            )
        }
        return Route(name: name, waypoints: waypoints)
    }
}
