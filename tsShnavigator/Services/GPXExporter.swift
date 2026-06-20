import Foundation
import CoreLocation

struct GPXExporter {
    static func gpxString(name: String, locations: [CLLocation]) -> String {
        let escapedName = name
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let trackpoints = locations.map { loc -> String in
            let lat = String(format: "%.7f", loc.coordinate.latitude)
            let lon = String(format: "%.7f", loc.coordinate.longitude)
            var trkpt = "      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">"
            if loc.verticalAccuracy >= 0 {
                trkpt += "\n        <ele>\(String(format: "%.1f", loc.altitude))</ele>"
            }
            trkpt += "\n        <time>\(iso8601(loc.timestamp))</time>"
            trkpt += "\n      </trkpt>"
            return trkpt
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="tsShnavigator" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escapedName)</name>
            <time>\(iso8601(Date()))</time>
          </metadata>
          <trk>
            <name>\(escapedName)</name>
            <trkseg>
        \(trackpoints)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    static func gpxFileURL(name: String, locations: [CLLocation]) -> URL? {
        guard let data = gpxString(name: name, locations: locations).data(using: .utf8) else { return nil }
        let filename = name.replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "_", options: .regularExpression) + ".gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
