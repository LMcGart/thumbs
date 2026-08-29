import Foundation
import Places

/// Splits clusters into (kept, excluded). A cluster is excluded when clusters on
/// ≥ `minDistinctDays` distinct days sit within `radiusMeters` of its centroid —
/// that recurrence pattern is home or work, not restaurant visits. The radius is
/// deliberately wider than the match radius: indoor GPS scatters well past 75 m,
/// and a home that scatters must still hit the day threshold. A weekly favorite
/// (or your own dense block) can be caught too — the accepted cost of precision
/// over recall; tune with --home-days / --home-radius.
public func partitionFrequentLocations(
    _ clusters: [Cluster],
    minDistinctDays: Int = 5,
    radiusMeters: Double = 150,
    calendar: Calendar = .current
) -> (kept: [Cluster], excluded: [Cluster]) {
    let days = clusters.map { calendar.startOfDay(for: $0.start) }
    var kept: [Cluster] = []
    var excluded: [Cluster] = []
    for cluster in clusters {
        var distinctDays: Set<Date> = []
        for (otherIndex, other) in clusters.enumerated()
        where cluster.centroid.distance(to: other.centroid) <= radiusMeters {
            distinctDays.insert(days[otherIndex])
        }
        if distinctDays.count >= minDistinctDays {
            excluded.append(cluster)
        } else {
            kept.append(cluster)
        }
    }
    return (kept, excluded)
}
