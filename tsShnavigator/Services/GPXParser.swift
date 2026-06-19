import Foundation

enum GPXParseError: LocalizedError {
    case noTrackPoints
    case malformedFile

    var errorDescription: String? {
        switch self {
        case .noTrackPoints: return "No track points found in GPX file."
        case .malformedFile: return "The file could not be parsed as a GPX file."
        }
    }
}

final class GPXParser: NSObject, XMLParserDelegate {
    private var waypoints: [Waypoint] = []
    private var routeName: String = "Untitled Route"

    // Current element state
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var currentElement: String = ""
    private var currentText: String = ""
    private var insideTrkpt = false

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parse(data: Data) throws -> (name: String, waypoints: [Waypoint]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { throw GPXParseError.malformedFile }
        guard !waypoints.isEmpty else { throw GPXParseError.noTrackPoints }
        return (routeName, waypoints)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        currentElement = element
        currentText = ""
        if element == "trkpt" || element == "wpt" || element == "rtept" {
            insideTrkpt = true
            currentLat = attributes["lat"].flatMap(Double.init)
            currentLon = attributes["lon"].flatMap(Double.init)
            currentEle = nil
            currentTime = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch element {
        case "name":
            if !insideTrkpt && !text.isEmpty {
                routeName = text
            }
        case "ele":
            currentEle = Double(text)
        case "time":
            if insideTrkpt {
                currentTime = Self.iso8601.date(from: text)
            }
        case "trkpt", "wpt", "rtept":
            if let lat = currentLat, let lon = currentLon {
                waypoints.append(Waypoint(latitude: lat, longitude: lon,
                                          elevation: currentEle, timestamp: currentTime))
            }
            insideTrkpt = false
        default:
            break
        }
        currentText = ""
    }
}
