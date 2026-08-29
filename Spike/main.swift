import Detection
import Foundation
import Places

// Spike pipeline: photos -> clusters -> home/work exclusion -> POI match ->
// Vision food check -> confidence -> docs/private/spike-report.md.
// Run from the repo root. See docs/roadmap.md item 3.

var windowDays = 365
var dbPath = "docs/private/places.sqlite"
var outPath = "docs/private/spike-report.md"
var homeMinDays = 5
var matchRadius = 75.0

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
    case "--radius": matchRadius = Double(value()) ?? matchRadius
    default:
        print("Usage: Spike [--days 365] [--db path] [--out path] [--home-days 5] [--radius 75]")
        exit(64)
    }
}

let clock = ContinuousClock()
let started = clock.now

do {
    let store = try PlaceStore(path: dbPath)

    let samples = try await fetchPhotoSamples(days: windowDays)
    let located = samples.filter { $0.location != nil }
    print("Photos: \(samples.count) in the last \(windowDays) days, \(located.count) with location")

    let clusters = clusterPhotos(samples)
    let (kept, excluded) = partitionFrequentLocations(clusters, minDistinctDays: homeMinDays)
    print("Clusters: \(clusters.count) (\(excluded.count) excluded as frequent locations)")

    var visits: [DetectedVisit] = []
    for (index, cluster) in kept.enumerated() {
        let candidates = try store.places(near: cluster.centroid, withinMeters: matchRadius)
        // One photo per cluster; the middle one is most likely mid-meal.
        let middlePhoto = cluster.photos[cluster.photos.count / 2]
        let food = await photoLooksLikeFood(assetID: middlePhoto.id)
        visits.append(DetectedVisit(cluster: cluster, candidates: candidates, foodPhotoFound: food))
        if (index + 1) % 25 == 0 { print("  matched \(index + 1)/\(kept.count)") }
    }

    let report = renderSpikeReport(visits: visits, excluded: excluded, windowDays: windowDays, generatedAt: Date())
    try report.write(toFile: outPath, atomically: true, encoding: .utf8)

    let elapsed = started.duration(to: clock.now)
    print("Wrote \(outPath): \(visits.count) clusters in \(elapsed.formatted(.units(allowed: [.minutes, .seconds])))")
} catch {
    print("Spike failed: \(error)")
    exit(1)
}
