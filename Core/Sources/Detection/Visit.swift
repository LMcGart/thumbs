import Foundation
import Places

public enum Confidence: String, Sendable {
    case high
    case ambiguous
    case low
}

/// A cluster after place matching. Candidates are nearest first.
public struct DetectedVisit: Sendable {
    public let cluster: Cluster
    public let candidates: [NearbyPlace]
    public let foodPhotoFound: Bool
    public let confidence: Confidence

    /// Detection spec: single candidate + ≥2 photos + a food photo = high;
    /// multiple candidates = ambiguous (surface as "X or Y?", never guess);
    /// otherwise low (do not surface). Precision over recall.
    public init(cluster: Cluster, candidates: [NearbyPlace], foodPhotoFound: Bool) {
        self.cluster = cluster
        self.candidates = candidates
        self.foodPhotoFound = foodPhotoFound
        if candidates.count > 1 {
            self.confidence = .ambiguous
        } else if candidates.count == 1, cluster.photos.count >= 2, foodPhotoFound {
            self.confidence = .high
        } else {
            self.confidence = .low
        }
    }
}
