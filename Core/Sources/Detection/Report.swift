import Foundation
import Places

/// Renders the spike report: every kept cluster sorted by date, then a summary
/// of excluded frequent locations. The reader verifies rows from memory, so
/// each row links to the centroid in Apple Maps.
public func renderSpikeReport(
    visits: [DetectedVisit],
    excluded: [Cluster],
    windowDays: Int,
    generatedAt: Date
) -> String {
    let sorted = visits.sorted { $0.cluster.start < $1.cluster.start }
    var lines: [String] = []
    lines.append("# Spike report — visit detection")
    lines.append("")
    let counts = Dictionary(grouping: sorted, by: \.confidence).mapValues(\.count)
    lines.append(
        "Window: last \(windowDays) days · Generated \(day(generatedAt)) · "
        + "\(sorted.count) clusters (high \(counts[.high, default: 0]) · ambiguous \(counts[.ambiguous, default: 0]) · "
        + "low \(counts[.low, default: 0])) · \(excluded.count) excluded as frequent locations"
    )
    lines.append("")
    lines.append("| Date | Best candidate | Alternatives | Confidence | Photos | Food? | Map |")
    lines.append("|---|---|---|---|---|---|---|")
    for visit in sorted {
        let best = visit.candidates.first.map(describe) ?? "—"
        let alternatives = visit.candidates.dropFirst()
        var alternativesText = alternatives.prefix(3).map(describe).joined(separator: " · ")
        if alternatives.count > 3 { alternativesText += " · +\(alternatives.count - 3) more" }
        if alternativesText.isEmpty { alternativesText = "—" }
        lines.append(
            "| \(dateTime(visit.cluster.start)) | \(best) | \(alternativesText) "
            + "| \(visit.confidence.rawValue) | \(visit.cluster.photos.count) | \(visit.foodPhotoFound ? "yes" : "no") "
            + "| \(mapLink(visit.cluster.centroid)) |"
        )
    }
    if !excluded.isEmpty {
        lines.append("")
        lines.append("## Excluded frequent locations (home/work)")
        lines.append("")
        lines.append("| Location | Clusters | Days | First | Last | Map |")
        lines.append("|---|---|---|---|---|---|")
        for group in groupExcluded(excluded) {
            lines.append(
                "| \(coordinateText(group.centroid)) | \(group.clusters.count) | \(group.dayCount) "
                + "| \(day(group.first)) | \(day(group.last)) "
                + "| \(mapLink(group.centroid)) |"
            )
        }
    }
    lines.append("")
    return lines.joined(separator: "\n")
}

private func describe(_ candidate: NearbyPlace) -> String {
    let name = candidate.place.name.replacingOccurrences(of: "|", with: "\\|")
    return "\(name) (\(Int(candidate.distanceMeters.rounded())) m)"
}

private func mapLink(_ coordinate: Coordinate) -> String {
    "[map](https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude))"
}

private func coordinateText(_ coordinate: Coordinate) -> String {
    String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
}

private struct ExcludedGroup {
    var clusters: [Cluster]
    var centroid: Coordinate { clusters[0].centroid }
    var dayCount: Int { Set(clusters.map { day($0.start) }).count }
    var first: Date { clusters.map(\.start).min()! }
    var last: Date { clusters.map(\.start).max()! }
}

/// Excluded clusters are mostly hundreds of rows at two spots; collapse to one
/// row per ~75 m location so the section stays readable.
private func groupExcluded(_ excluded: [Cluster]) -> [ExcludedGroup] {
    var groups: [ExcludedGroup] = []
    for cluster in excluded {
        if let index = groups.firstIndex(where: { $0.centroid.distance(to: cluster.centroid) <= 75 }) {
            groups[index].clusters.append(cluster)
        } else {
            groups.append(ExcludedGroup(clusters: [cluster]))
        }
    }
    return groups.sorted { $0.clusters.count > $1.clusters.count }
}

// Fixed-format, current time zone: report rows must be stable and greppable.
// Built per call — DateFormatter is not Sendable, so no shared global under
// strict concurrency; rendering happens once per run.
private func format(_ date: Date, _ pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = pattern
    return formatter.string(from: date)
}

private func dateTime(_ date: Date) -> String { format(date, "yyyy-MM-dd HH:mm") }
private func day(_ date: Date) -> String { format(date, "yyyy-MM-dd") }
