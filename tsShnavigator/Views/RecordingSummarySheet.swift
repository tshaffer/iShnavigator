import SwiftUI

struct RecordingSummarySheet: View {
    let recordingManager: RecordingManager
    let onSave: (String) -> Void
    let onDiscard: () -> Void

    @State private var routeName: String = ""
    @State private var saved = false
    @State private var shareURL: URL?
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Route Name") {
                    TextField("Name", text: $routeName)
                }

                Section("Summary") {
                    LabeledContent("Distance", value: formatDistance(recordingManager.elapsedDistance))
                    LabeledContent("Duration", value: formatDuration(recordingManager.elapsedSeconds))
                    LabeledContent("Points", value: "\(recordingManager.recordedLocations.count)")
                }

                Section {
                    Button {
                        if !saved {
                            onSave(routeName)
                            saved = true
                        }
                    } label: {
                        Label(
                            saved ? "Saved to Routes ✓" : "Save to Routes",
                            systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down"
                        )
                        .foregroundStyle(saved ? Color.secondary : Color.accentColor)
                    }
                    .disabled(saved)

                    Button {
                        if let url = GPXExporter.gpxFileURL(name: routeName, locations: recordingManager.recordedLocations) {
                            shareURL = url
                            showingShare = true
                        }
                    } label: {
                        Label("Share GPX…", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onDiscard()
                    } label: {
                        Label("Discard Recording", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Recording Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDiscard() }
                }
            }
        }
        .onAppear {
            routeName = defaultName()
        }
        .sheet(isPresented: $showingShare) {
            if let url = shareURL {
                ShareSheet(url: url)
            }
        }
    }

    private func defaultName() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy h:mm a"
        return "Recording – \(f.string(from: Date()))"
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        return miles >= 0.1 ? String(format: "%.2f mi", miles) : String(format: "%.0f ft", meters * 3.28084)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
