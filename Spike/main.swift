import Detection
import Foundation
import Places

// Spike CLI: runs the shared detection pipeline against the local Photos
// library and writes docs/private/spike-report.md. Run from the repo root.

var windowDays = 365
var dbPath = "docs/private/places.sqlite"
var outPath = "docs/private/spike-report.md"
var homeMinDays = 5
var homeRadius = 150.0
var matchRadius = 75.0
var foodThreshold: Float = 0.3

var arguments = Array(CommandLine.arguments.dropFirst())
while !arguments.isEmpty {
    let flag = arguments.removeFirst()
    func value() -> String {
        guard !arguments.isEmpty else { fatalError("Missing value for \(flag)") }
        return arguments.removeFirst()
    }
    switch flag {
    case "--days": windowDays = Int(value()) ?? windowDays
    case "--db": dbPath = value()
    case "--out": outPath = value()
    case "--home-days": homeMinDays = Int(value()) ?? homeMinDays
    case "--home-radius": homeRadius = Double(value()) ?? homeRadius
    case "--radius": matchRadius = Double(value()) ?? matchRadius
    case "--food-threshold": foodThreshold = Float(value()) ?? foodThreshold
    default:
        print("Usage: Spike [--days 365] [--db path] [--out path] [--home-days 5] [--home-radius 150] [--radius 75] [--food-threshold 0.3]")
        exit(64)
    }
}

let clock = ContinuousClock()
let started = clock.now

do {
    let store = try PlaceStore(path: dbPath)
    let result = try await runDetectionPipeline(
        store: store,
        windowDays: windowDays,
        matchRadiusMeters: matchRadius,
        homeMinDays: homeMinDays,
        homeRadiusMeters: homeRadius,
        foodThreshold: foodThreshold,
        progress: { print($0) }
    )
    let report = renderSpikeReport(visits: result.visits, excluded: result.excluded, windowDays: windowDays, generatedAt: Date())
    try report.write(toFile: outPath, atomically: true, encoding: .utf8)
    print(result.stats.summary)
    let elapsed = started.duration(to: clock.now)
    print("Wrote \(outPath): \(result.visits.count) clusters in \(elapsed.formatted(.units(allowed: [.minutes, .seconds])))")
} catch {
    print("Spike failed: \(error)")
    exit(1)
}
