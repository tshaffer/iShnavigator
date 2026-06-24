import SwiftUI
import MapKit

struct RouteMapView: View {
    let route: Route?
    let locationManager: LocationManager
    let recordingManager: RecordingManager
    let onSaveRecording: (String) -> Void
    let onDismiss: (() -> Void)?
    @Binding var mapTileStyle: MapTileStyle

    @State private var recenterID = UUID()
    @State private var showingSummary = false

    init(route: Route? = nil,
         locationManager: LocationManager,
         recordingManager: RecordingManager,
         onSaveRecording: @escaping (String) -> Void,
         onDismiss: (() -> Void)? = nil,
         mapTileStyle: Binding<MapTileStyle>) {
        self.route = route
        self.locationManager = locationManager
        self.recordingManager = recordingManager
        self.onSaveRecording = onSaveRecording
        self.onDismiss = onDismiss
        self._mapTileStyle = mapTileStyle
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MapKitView(
                route: route,
                recordedCoordinates: recordingManager.recordedCoordinates,
                tileStyle: mapTileStyle,
                initialRegion: route?.region,
                recenterID: recenterID
            )
            .ignoresSafeArea()

            recordingControls
                .padding(.bottom, 32)
        }
        .navigationTitle(route?.name ?? "Record Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    // Map style picker
                    Menu {
                        ForEach(MapTileStyle.allCases) { style in
                            Button {
                                mapTileStyle = style
                            } label: {
                                Label(
                                    style.rawValue + (style == mapTileStyle ? " ✓" : ""),
                                    systemImage: style.systemImage
                                )
                            }
                            .disabled(style.requiresAPIKey && !style.apiKeyConfigured)
                        }
                    } label: {
                        Image(systemName: "map.circle")
                    }

                    // Recenter button
                    Button {
                        recenterID = UUID()
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                    }
                }
            }
        }
        .onAppear {
            locationManager.requestPermissionAndStart()
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            if let loc = newLocation {
                recordingManager.addLocation(loc)
            }
        }
        .sheet(isPresented: $showingSummary) {
            RecordingSummarySheet(
                recordingManager: recordingManager,
                onSave: { name in onSaveRecording(name) },
                onDone: {
                    showingSummary = false
                    recordingManager.discard()
                    onDismiss?()
                }
            )
        }
    }

    @ViewBuilder
    private var recordingControls: some View {
        switch recordingManager.state {
        case .idle:
            Button {
                recordingManager.start()
            } label: {
                Label("Record", systemImage: "record.circle")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.red, in: Capsule())
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }

        case .recording:
            HStack(spacing: 16) {
                Text(formatDuration(recordingManager.elapsedSeconds))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())

                Text(formatDistance(recordingManager.elapsedDistance))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())

                Button {
                    recordingManager.stop()
                    showingSummary = true
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                        .background(Circle().fill(.white))
                        .shadow(radius: 4)
                }
            }

        case .finished:
            EmptyView()
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        return miles >= 0.1 ? String(format: "%.2f mi", miles) : String(format: "%.0f ft", meters * 3.28084)
    }
}
