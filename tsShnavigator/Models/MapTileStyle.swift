import Foundation


enum MapTileStyle: String, CaseIterable, Identifiable {
    case standard      = "Standard"
    case hybrid        = "Hybrid"
    case satellite     = "Satellite"
    case openTopoMap   = "OpenTopoMap"
    case thunderforest = "Thunderforest Outdoors"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .standard:      return "map"
        case .hybrid:        return "map.fill"
        case .satellite:     return "globe.americas.fill"
        case .openTopoMap:   return "mountain.2.fill"
        case .thunderforest: return "bicycle"
        }
    }

    var tileURLTemplate: String? {
        switch self {
        case .standard, .hybrid, .satellite:
            return nil
        case .openTopoMap:
            return "https://tile.opentopomap.org/{z}/{x}/{y}.png"
        case .thunderforest:
            let key = Secrets.thunderforestAPIKey
            guard !key.isEmpty else { return nil }
            return "https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey=\(key)"
        }
    }

    var requiresAPIKey: Bool { self == .thunderforest }

    var apiKeyConfigured: Bool {
        guard requiresAPIKey else { return true }
        return !Secrets.thunderforestAPIKey.isEmpty
    }
}
