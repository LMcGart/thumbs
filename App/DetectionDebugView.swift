import Detection
import Places
import SwiftUI

// Dev-only screen for the on-device detection spike (roadmap 3b follow-up):
// runs the shared pipeline against this phone's photo library and shows the
// same sections and stats as docs/private/spike-report.md for comparison.
struct DetectionDebugView: View {
    @State private var log: [String] = []
    @State private var result: PipelineResult?
    @State private var elapsed: Duration?
    @State private var running = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if !log.isEmpty {
                    Section("Log") {
                        ForEach(log.suffix(10), id: \.self) { line in
                            Text(line).font(.caption.monospaced())
                        }
                    }
                }
                if let result {
                    resultSections(result)
                }
            }
            .navigationTitle("Detection spike")
            .toolbar {
                Button(running ? "Running…" : "Run") { Task { await run() } }
                    .disabled(running)
            }
        }
    }

    @ViewBuilder
    private func resultSections(_ result: PipelineResult) -> some View {
        let sorted = result.visits.sorted { $0.cluster.start < $1.cluster.start }
        let groups: [(String, [DetectedVisit])] = [
            ("Widget would show", sorted.filter { $0.confidence == .high }),
            ("Widget would ask “X or Y?”", sorted.filter { $0.confidence == .ambiguous }),
            ("Hidden", sorted.filter { $0.confidence == .low }),
        ]
        Section("Summary") {
            Text("\(result.visits.count) clusters · \(result.excluded.count) excluded as frequent locations")
            if let elapsed {
                Text("Ran in \(elapsed.formatted(.units(allowed: [.minutes, .seconds])))")
            }
            Text(result.stats.summary).font(.caption.monospaced())
        }
        ForEach(groups, id: \.0) { title, visits in
            Section("\(title) — \(visits.count)") {
                ForEach(Array(visits.enumerated()), id: \.offset) { _, visit in
                    row(visit)
                }
            }
        }
    }

    private func row(_ visit: DetectedVisit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(visit.cluster.start.formatted(date: .abbreviated, time: .shortened))
                .font(.caption).foregroundStyle(.secondary)
            if let best = visit.candidates.first {
                Text("\(best.place.name) (\(Int(best.distanceMeters.rounded())) m)")
            } else {
                Text("no candidate").foregroundStyle(.secondary)
            }
            Text("\(visit.cluster.photos.count) photos · food \(visit.foodPhotoFound ? "yes" : "no") · \(max(visit.candidates.count - 1, 0)) alternatives")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func run() async {
        running = true
        errorMessage = nil
        log = []
        defer { running = false }
        guard let dbURL = Bundle.main.url(forResource: "places", withExtension: "sqlite") else {
            errorMessage = "places.sqlite is not bundled — run scripts/build-places-db.sh, then xcodegen generate and rebuild."
            return
        }
        do {
            let store = try PlaceStore(path: dbURL.path)
            let clock = ContinuousClock()
            let started = clock.now
            result = try await runDetectionPipeline(store: store, progress: { log.append($0) })
            elapsed = started.duration(to: clock.now)
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
