import Foundation
import Observation

enum LoadingState {
    case idle
    case loading
    case error(String)
}

@Observable
final class AppViewModel {
    var routes: [Route] = []
    var selectedRoute: Route?
    var importState: LoadingState = .idle
    var showingFilePicker = false
    var showingRecording = false
    let locationManager = LocationManager()
    let recordingManager = RecordingManager()

    init() {
        loadPersistedRoutes()
    }

    // MARK: - GPX Import

    func importGPX(from url: URL) {
        importState = .loading
        Task {
            do {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let parser = GPXParser()
                let (name, waypoints) = try parser.parse(data: data)
                let route = Route(name: name, waypoints: waypoints)
                await MainActor.run {
                    routes.insert(route, at: 0)
                    persistRoutes()
                    importState = .idle
                }
            } catch {
                await MainActor.run {
                    importState = .error(error.localizedDescription)
                }
            }
        }
    }

    func saveRecording(name: String) {
        let route = recordingManager.toRoute(name: name)
        routes.insert(route, at: 0)
        persistRoutes()
    }

    func deleteRoutes(at offsets: IndexSet) {
        routes.remove(atOffsets: offsets)
        persistRoutes()
    }

    func selectRoute(_ route: Route) {
        selectedRoute = route
    }

    // MARK: - Persistence

    private func loadPersistedRoutes() {
        guard let data = UserDefaults.standard.data(forKey: "savedRoutes"),
              let decoded = try? JSONDecoder().decode([Route].self, from: data) else { return }
        routes = decoded
    }

    private func persistRoutes() {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        UserDefaults.standard.set(data, forKey: "savedRoutes")
    }
}
