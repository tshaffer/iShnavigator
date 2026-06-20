import SwiftUI
import MapKit

struct HeadingAnnotation: View {
    let headingDegrees: Double

    var body: some View {
        ZStack {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue.opacity(0.8))
                .offset(y: -18)
                .rotationEffect(.degrees(headingDegrees))

            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(.blue).padding(3))
                .shadow(radius: 2)
        }
    }
}

struct RouteMapView: View {
    let route: Route?
    let locationManager: LocationManager
    let recordingManager: RecordingManager
    let onSaveRecording: (String) -> Void

    @State private var position: MapCameraPosition
    @State private var showingSummary = false

    init(route: Route? = nil, locationManager: LocationManager, recordingManager: RecordingManager, onSaveRecording: @escaping (String) -> Void) {
        self.route = route
        self.locationManager = locationManager
        self.recordingManager = recordingManager
        self.onSaveRecording = onSaveRecording
        if let region = route?.region {
            _position = State(initialValue: .region(region))
        } else {
            _position = State(initialValue: .userLocation(fallback: .automatic))
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                // Planned route — orange (only when navigating an existing route)
                if let route {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }

                // Recorded track — green
                if !recordingManager.recordedCoordinates.isEmpty {
                    MapPolyline(coordinates: recordingManager.recordedCoordinates)
                        .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }

                // User location dot + heading
                if let location = locationManager.currentLocation {
                    let coord = location.coordinate
                    if let heading = locationManager.heading, heading.headingAccuracy >= 0 {
                        Annotation("", coordinate: coord) {
                            HeadingAnnotation(headingDegrees: heading.trueHeading)
                        }
                    } else {
                        Annotation("", coordinate: coord) {
                            Circle()
                                .fill(.white)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().fill(.blue).padding(3))
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // Recording controls overlay
            recordingControls
                .padding(.bottom, 32)
        }
        .navigationTitle(route?.name ?? "Record Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    recenterOnRoute()
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
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
                onSave: { name in
                    onSaveRecording(name)
                },
                onDiscard: {
                    showingSummary = false
                    recordingManager.discard()
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
                // Elapsed timer
                Text(formatDuration(recordingManager.elapsedSeconds))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())

                // Distance
                Text(formatDistance(recordingManager.elapsedDistance))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())

                // Stop button
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

    private func recenterOnRoute() {
        if let region = route?.region {
            withAnimation { position = .region(region) }
        } else {
            withAnimation { position = .userLocation(fallback: .automatic) }
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
