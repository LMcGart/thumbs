import Foundation
import Places

/// Food-check bookkeeping across a run, kept so spike runs on different
/// platforms (Mac CLI vs on-device) can be compared number-for-number.
public struct FoodCheckStats: Sendable {
    public var scores: [Float] = []
    public var imageWidths: [Int] = []
    public var failures: [String: Int] = [:]

    public var summary: String {
        var lines: [String] = []
        if !scores.isEmpty {
            let sorted = scores.sorted()
            func pct(_ q: Double) -> String { String(format: "%.2f", sorted[Int(Double(sorted.count - 1) * q)]) }
            lines.append("Food scores (\(sorted.count) photos): p25 \(pct(0.25)) · p50 \(pct(0.5)) · p75 \(pct(0.75)) · p90 \(pct(0.9)) · max \(pct(1.0))")
            lines.append("Image widths: median \(imageWidths.sorted()[imageWidths.count / 2])px")
        }
        if !failures.isEmpty {
            lines.append("Failures: \(failures.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }
}

public struct PipelineResult {
    public let visits: [DetectedVisit]
    public let excluded: [Cluster]
    public let photoCount: Int
    public let locatedCount: Int
    public let stats: FoodCheckStats
}

/// The whole detection pipeline: photos → clusters → frequent-location
/// exclusion → POI match → food check → confidence. Shared by the macOS Spike
/// CLI and the on-device debug screen so both measure the same thing.
@MainActor
public func runDetectionPipeline(
    store: PlaceStore,
    windowDays: Int = 365,
    matchRadiusMeters: Double = 75,
    homeMinDays: Int = 5,
    homeRadiusMeters: Double = 150,
    foodThreshold: Float = 0.3,
    progress: (String) -> Void = { _ in }
) async throws -> PipelineResult {
    let samples = try await fetchPhotoSamples(days: windowDays)
    let located = samples.filter { $0.location != nil }
    progress("Photos: \(samples.count) in the last \(windowDays) days, \(located.count) with location")

    let clusters = clusterPhotos(samples)
    let (kept, excluded) = partitionFrequentLocations(clusters, minDistinctDays: homeMinDays, radiusMeters: homeRadiusMeters)
    progress("Clusters: \(clusters.count) (\(excluded.count) excluded as frequent locations)")

    var visits: [DetectedVisit] = []
    var stats = FoodCheckStats()
    var samplesLogged = 0
    for (index, cluster) in kept.enumerated() {
        let candidates = rankCandidates(try store.places(near: cluster.centroid, withinMeters: matchRadiusMeters))
        // One photo per cluster; the middle one is most likely mid-meal.
        let middlePhoto = cluster.photos[cluster.photos.count / 2]
        var isFood = false
        switch await checkFood(assetID: middlePhoto.id) {
        case .classified(let score, let width, let top):
            isFood = score >= foodThreshold
            stats.scores.append(score)
            stats.imageWidths.append(width)
            if !isFood, score >= 0.1, samplesLogged < 8 {
                progress("  borderline (food \(String(format: "%.2f", score)), \(width)px): \(top.joined(separator: ", "))")
                samplesLogged += 1
            }
        case .assetMissing:
            stats.failures["asset missing", default: 0] += 1
        case .imageUnavailable(let message):
            stats.failures["image unavailable", default: 0] += 1
            if samplesLogged < 8 { progress("  image unavailable: \(message)"); samplesLogged += 1 }
        case .visionFailed(let message):
            stats.failures["vision failed", default: 0] += 1
            if samplesLogged < 8 { progress("  vision failed: \(message)"); samplesLogged += 1 }
        }
        visits.append(DetectedVisit(cluster: cluster, candidates: candidates, foodPhotoFound: isFood))
        if (index + 1) % 100 == 0 { progress("  matched \(index + 1)/\(kept.count)") }
    }
    return PipelineResult(visits: visits, excluded: excluded, photoCount: samples.count, locatedCount: located.count, stats: stats)
}
