import Foundation
import Places

/// Orders candidates for presentation (gate 3a): source confidence breaks
/// near-ties in distance, and name-duplicates are collapsed.
public func rankCandidates(_ candidates: [NearbyPlace]) -> [NearbyPlace] {
    let ranked = candidates.sorted { score($0) < score($1) }
    var result: [NearbyPlace] = []
    for candidate in ranked {
        let name = normalized(candidate.place.name)
        let isDuplicate = result.contains { existing in
            let kept = normalized(existing.place.name)
            return name == kept
                || (min(name.count, kept.count) >= 4 && (name.hasPrefix(kept) || kept.hasPrefix(name)))
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

/// "Maman" / "Maman Nyc" / "Cafe Kitsune Inc." are the same place: lowercase,
/// strip punctuation and filler tokens, then compare with whole-name prefixes.
private func normalized(_ name: String) -> String {
    name.lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty && !["nyc", "inc", "llc", "co", "corp"].contains($0) }
        .joined(separator: " ")
}
