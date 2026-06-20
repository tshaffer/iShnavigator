import SwiftUI
import CoreLocation

struct RouteListView: View {
    @State var vm: AppViewModel

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if vm.routes.isEmpty {
                emptyState
            } else {
                routeList
            }
        }
        .navigationTitle("tsShnavigator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        vm.showingRecording = true
                    } label: {
                        Image(systemName: "record.circle")
                            .foregroundStyle(.red)
                    }
                    Button {
                        vm.showingFilePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $vm.showingFilePicker,
            allowedContentTypes: [.init(importedAs: "com.topografix.gpx"), .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    vm.importGPX(from: url)
                }
            case .failure:
                break
            }
        }
        .overlay {
            if case .loading = vm.importState {
                ProgressView("Importing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Import Failed", isPresented: .init(
            get: { if case .error = vm.importState { return true }; return false },
            set: { if !$0 { vm.importState = .idle } }
        )) {
            Button("OK") { vm.importState = .idle }
        } message: {
            if case .error(let msg) = vm.importState {
                Text(msg)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Routes Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Import a GPX file to get started")
                .foregroundStyle(.secondary)
            Button {
                vm.showingFilePicker = true
            } label: {
                Label("Import GPX", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var routeList: some View {
        List {
            ForEach(vm.routes) { route in
                NavigationLink(value: route) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name)
                            .font(.headline)
                        HStack(spacing: 12) {
                            Label(formatDistance(route.totalDistanceMeters), systemImage: "arrow.left.and.right")
                            Label("\(route.waypoints.count) pts", systemImage: "mappin")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text("Imported \(Self.dateFormatter.string(from: route.importedAt))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                .swipeActions(edge: .leading) {
                    if let url = gpxURL(for: route) {
                        ShareLink(item: url) {
                            Label("Share GPX", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                }
            }
            .onDelete(perform: vm.deleteRoutes)
        }
    }

    private func gpxURL(for route: Route) -> URL? {
        let locations = route.waypoints.map { wp -> CLLocation in
            let coord = CLLocationCoordinate2D(latitude: wp.latitude, longitude: wp.longitude)
            return CLLocation(
                coordinate: coord,
                altitude: wp.elevation ?? 0,
                horizontalAccuracy: 5,
                verticalAccuracy: wp.elevation != nil ? 5 : -1,
                timestamp: wp.timestamp ?? Date()
            )
        }
        return GPXExporter.gpxFileURL(name: route.name, locations: locations)
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        }
        return String(format: "%.0f ft", meters * 3.28084)
    }
}
