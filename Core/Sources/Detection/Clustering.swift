import Foundation
import Places

/// A photo asset reduced to what clustering needs. `location` is nil for
/// assets without GPS data; clustering drops those.
public struct PhotoSample: Sendable, Hashable, Identifiable {
    public let id: String
    public let date: Date
    public let location: Coordinate?

    public init(id: String, date: Date, location: Coordinate?) {
        self.id = id
        self.date = date
        self.location = location
    }
}

/// A group of photos taken close together in time and space — a visit candidate.
public struct Cluster: Sendable {
    /// Sorted by date, all with a location.
    public let photos: [PhotoSample]
    public let centroid: Coordinate
    public let start: Date
    public let end: Date
}

/// Groups photos into visit candidates. A photo joins the open cluster when it is
/// within `maxTimeGap` of the cluster's latest photo (gap to the previous photo,
/// not to the cluster start, so a long meal photographed throughout stays one
/// cluster) and within `maxDistanceMeters` of the cluster's running centroid
/// (not the previous photo, so small steps can't chain across a neighborhood).
/// Defaults are the detection spec's starting thresholds; tune against ground truth.
public func clusterPhotos(
    _ samples: [PhotoSample],
    maxTimeGap: TimeInterval = 2 * 60 * 60,
    maxDistanceMeters: Double = 50
) -> [Cluster] {
    let located = samples
        .compactMap { sample in sample.location.map { (sample: sample, location: $0) } }
        .sorted { $0.sample.date < $1.sample.date }

    var groups: [[(sample: PhotoSample, location: Coordinate)]] = []
    for item in located {
        if let open = groups.last, let previous = open.last,
           item.sample.date.timeIntervalSince(previous.sample.date) <= maxTimeGap,
           item.location.distance(to: centroid(of: open.map(\.location))) <= maxDistanceMeters {
            groups[groups.count - 1].append(item)
        } else {
            groups.append([item])
        }
    }

    return groups.map { group in
        Cluster(
            photos: group.map(\.sample),
            centroid: centroid(of: group.map(\.location)),
            start: group.first!.sample.date,
            end: group.last!.sample.date
        )
    }
}

/// Arithmetic mean of the coordinates — fine at visit scale (tens of meters).
private func centroid(of coordinates: [Coordinate]) -> Coordinate {
    Coordinate(
        latitude: coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count),
        longitude: coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
    )
}
