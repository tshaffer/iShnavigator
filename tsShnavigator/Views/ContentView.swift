import SwiftUI

struct ContentView: View {
    @State private var vm = AppViewModel()

    var body: some View {
        NavigationStack {
            RouteListView(vm: vm)
                .navigationDestination(for: Route.self) { route in
                    RouteMapView(
                        route: route,
                        locationManager: vm.locationManager,
                        recordingManager: vm.recordingManager,
                        onSaveRecording: { name in vm.saveRecording(name: name) }
                    )
                }
        }
    }
}
