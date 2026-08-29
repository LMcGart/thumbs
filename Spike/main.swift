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
    case "--radius": matchRadius = Double(value()) ?? matchRadius
    case "--food-threshold": foodThreshold = Float(value()) ?? foodThreshold
    default:
        print("Usage: Spike [--days 365] [--db path] [--out path] [--home-days 5] [--radius 75] [--food-threshold 0.3]")
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
    var failures: [String: Int] = [:]
    var foodScores: [Float] = []
    var widths: [Int] = []
    var samplesLogged = 0
    for (index, cluster) in kept.enumerated() {
        let candidates = rankCandidates(try store.places(near: cluster.centroid, withinMeters: matchRadius))
        // One photo per cluster; the middle one is most likely mid-meal.
        let middlePhoto = cluster.photos[cluster.photos.count / 2]
        var isFood = false
        switch await checkFood(assetID: middlePhoto.id) {
        case .classified(let score, let width, let top):
            isFood = score >= foodThreshold
            foodScores.append(score)
            widths.append(width)
            if !isFood, score >= 0.1, samplesLogged < 8 {
                print("  borderline (food \(String(format: "%.2f", score)), \(width)px): \(top.joined(separator: ", "))")
                samplesLogged += 1
            }
        case .assetMissing: failures["asset missing", default: 0] += 1
        case .imageUnavailable(let message):
            failures["image unavailable", default: 0] += 1
            if samplesLogged < 8 { print("  image unavailable: \(message)"); samplesLogged += 1 }
        case .visionFailed(let message):
            failures["vision failed", default: 0] += 1
            if samplesLogged < 8 { print("  vision failed: \(message)"); samplesLogged += 1 }
        }
        visits.append(DetectedVisit(cluster: cluster, candidates: candidates, foodPhotoFound: isFood))
        if (index + 1) % 100 == 0 { print("  matched \(index + 1)/\(kept.count)") }
    }
    if !foodScores.isEmpty {
        let sorted = foodScores.sorted()
        func pct(_ q: Double) -> String { String(format: "%.2f", sorted[Int(Double(sorted.count - 1) * q)]) }
        let over = foodScores.filter { $0 >= foodThreshold }.count
        print("Food scores (\(sorted.count) photos): p25 \(pct(0.25)) · p50 \(pct(0.5)) · p75 \(pct(0.75)) · p90 \(pct(0.9)) · max \(pct(1.0)) · >=\(foodThreshold): \(over)")
        print("Image widths: median \(widths.sorted()[widths.count / 2])px")
    }
    if !failures.isEmpty {
        print("Failures: \(failures.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")
    }

    let report = renderSpikeReport(visits: visits, excluded: excluded, windowDays: windowDays, generatedAt: Date())
    try report.write(toFile: outPath, atomically: true, encoding: .utf8)

    let elapsed = started.duration(to: clock.now)
    print("Wrote \(outPath): \(visits.count) clusters in \(elapsed.formatted(.units(allowed: [.minutes, .seconds])))")
} catch {
    print("Spike failed: \(error)")
    exit(1)
}
