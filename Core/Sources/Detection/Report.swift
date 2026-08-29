import Foundation
import Places

/// Renders the spike report grouped the way the product would behave:
/// high → a widget card, ambiguous → an "X or Y?" question, low → never
/// surfaced (listed for diagnostics only). Excluded frequent locations last.
/// Each row links to the centroid in Apple Maps for verification.
public func renderSpikeReport(
    visits: [DetectedVisit],
    excluded: [Cluster],
    windowDays: Int,
    generatedAt: Date
) -> String {
    let sorted = visits.sorted { $0.cluster.start < $1.cluster.start }
    let high = sorted.filter { $0.confidence == .high }
    let ambiguous = sorted.filter { $0.confidence == .ambiguous }
    let low = sorted.filter { $0.confidence == .low }

    var lines: [String] = []
    lines.append("# Spike report — visit detection")
    lines.append("")
    lines.append(
        "Window: last \(windowDays) days · Generated \(day(generatedAt)) · \(sorted.count) clusters "
        + "· \(excluded.count) excluded as frequent locations"
    )
    lines.append("")
    lines.append("## Widget would show — \(high.count)")
    lines.append("")
    lines.append("One card per row: “Looks like you ate at ___ — rate it?”")
    lines.append("")
    lines.append(contentsOf: section(high))
    lines.append("## Widget would ask “X or Y?” — \(ambiguous.count)")
    lines.append("")
    lines.append("Shown as a question with the candidates below; the app never guesses.")
    lines.append("")
    lines.append(contentsOf: section(ambiguous))
    lines.append("## Hidden — \(low.count)")
    lines.append("")
    lines.append("Never surfaced in the app; listed here for spike diagnostics only.")
    lines.append("")
    lines.append(contentsOf: section(low))

    if !excluded.isEmpty {
        lines.append("## Excluded frequent locations (home/work)")
        lines.append("")
        lines.append("| Location | Clusters | Days | First | Last | Map |")
        lines.append("|---|---|---|---|---|---|")
        for group in groupExcluded(excluded) {
            lines.append(
                "| \(coordinateText(group.centroid)) | \(group.clusters.count) | \(group.dayCount) "
                + "| \(day(group.first)) | \(day(group.last)) | \(mapLink(group.centroid)) |"
            )
        }
        lines.append("")
    }
    return lines.joined(separator: "\n")
}

private func section(_ visits: [DetectedVisit]) -> [String] {
    guard !visits.isEmpty else { return ["None.", ""] }
    var lines = [
        "| Date | Best candidate | Alternatives | Photos | Food? | Map |",
        "|---|---|---|---|---|---|",
    ]
    for visit in visits {
        let best = visit.candidates.first.map(describe) ?? "—"
        let alternatives = visit.candidates.dropFirst()
        var alternativesText = alternatives.prefix(3).map(describe).joined(separator: " · ")
        if alternatives.count > 3 { alternativesText += " · +\(alternatives.count - 3) more" }
        if alternativesText.isEmpty { alternativesText = "—" }
        lines.append(
            "| \(dateTime(visit.cluster.start)) | \(best) | \(alternativesText) "
            + "| \(visit.cluster.photos.count) | \(visit.foodPhotoFound ? "yes" : "no") "
            + "| \(mapLink(visit.cluster.centroid)) |"
        )
    }
    lines.append("")
    return lines
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

/// Excluded clusters are mostly hundreds of rows at a few spots; collapse to
/// one row per location so the section stays readable.
private func groupExcluded(_ excluded: [Cluster]) -> [ExcludedGroup] {
    var groups: [ExcludedGroup] = []
    for cluster in excluded {
        if let index = groups.firstIndex(where: { $0.centroid.distance(to: cluster.centroid) <= 150 }) {
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
