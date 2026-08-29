import Foundation
import Places

/// Splits clusters into (kept, excluded). A cluster is excluded when clusters on
/// ≥ `minDistinctDays` distinct days sit within `radiusMeters` of its centroid —
/// that recurrence pattern is home or work, not restaurant visits. The threshold
/// is a starting value to tune at the gate; a weekly favorite can hit it too,
/// which is the accepted cost of precision over recall.
public func partitionFrequentLocations(
    _ clusters: [Cluster],
    minDistinctDays: Int = 5,
    radiusMeters: Double = 75,
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
