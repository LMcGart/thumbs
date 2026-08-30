import Foundation
import Places

/// Orders candidates for presentation (gate 3a): source confidence breaks
/// near-ties in distance, and name-duplicates are collapsed.
public func rankCandidates(_ candidates: [NearbyPlace]) -> [NearbyPlace] {
    let ranked = candidates.sorted { score($0) < score($1) }
    var result: [NearbyPlace] = []
    for candidate in ranked {
        let isDuplicate = result.contains { existing in
            placeNamesLikelyMatch(candidate.place.name, existing.place.name)
        }
        if !isDuplicate { result.append(candidate) }
    }
    return result
}

/// A low-confidence Overture row (junk, duplicate, likely gone) shouldn't
/// outrank a solid storefront a few meters farther: each missing point of
/// confidence costs up to 25 m of effective distance.
private func score(_ candidate: NearbyPlace) -> Double {
    candidate.distanceMeters + (1 - candidate.place.confidence) * 25
}
