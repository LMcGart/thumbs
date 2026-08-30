import Foundation
import Places

/// A place the user has already rated, as band-mate selection sees it.
public struct RatedPlace: Sendable, Identifiable, Hashable {
    public let id: Int64
    public let name: String
    public let category: PlaceCategory
    public let score: Int
    public let visitCount: Int
    public let lastVisitedAt: Date
    /// True once the rating was confirmed on the re-rank page (post-v1; always
    /// false until then, kept so selection priority doesn't change shape later).
    public let survivedRerank: Bool

    public init(id: Int64, name: String, category: PlaceCategory, score: Int, visitCount: Int, lastVisitedAt: Date, survivedRerank: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.score = score
        self.visitCount = visitCount
        self.lastVisitedAt = lastVisitedAt
        self.survivedRerank = survivedRerank
    }
}

public struct BandMateGroup: Sendable, Equatable {
    /// The stop these places sit at.
    public let score: Int
    /// nil for the current stop; "your 9s"-style label on fallback groups.
    public let label: String?
    public let places: [RatedPlace]
}

public struct BandMates: Sendable, Equatable {
    /// One group normally; the nearest bands above and below when the stop is empty.
    public let groups: [BandMateGroup]
    /// "no 8s yet" when the current stop is empty, else nil.
    public let emptyLabel: String?
}

/// Band-mates for a slider stop (spec: CLAUDE.md Rating). Same category only.
/// Priority: most visits, most recently visited, survived a re-rank. `rotation`
/// advances the selection window so the same places don't repeat every time.
public func bandMates(
    at score: Int,
    category: PlaceCategory,
    from rated: [RatedPlace],
    rotation: Int = 0,
    limit: Int = 3
) -> BandMates {
    let inCategory = rated.filter { $0.category == category }
    let band = prioritized(inCategory.filter { $0.score == score })
    if !band.isEmpty {
        return BandMates(groups: [BandMateGroup(score: score, label: nil, places: rotated(band, rotation: rotation, limit: limit))], emptyLabel: nil)
    }
    var groups: [BandMateGroup] = []
    if let above = ((score + 1)...10).first(where: { stop in inCategory.contains { $0.score == stop } }) {
        let places = rotated(prioritized(inCategory.filter { $0.score == above }), rotation: rotation, limit: limit)
        groups.append(BandMateGroup(score: above, label: "your \(above)s", places: places))
    }
    if score > 1, let below = stride(from: score - 1, through: 1, by: -1).first(where: { stop in inCategory.contains { $0.score == stop } }) {
        let places = rotated(prioritized(inCategory.filter { $0.score == below }), rotation: rotation, limit: limit)
        groups.append(BandMateGroup(score: below, label: "your \(below)s", places: places))
    }
    return BandMates(groups: groups, emptyLabel: "no \(score)s yet")
}

private func prioritized(_ places: [RatedPlace]) -> [RatedPlace] {
    places.sorted {
        if $0.visitCount != $1.visitCount { return $0.visitCount > $1.visitCount }
        if $0.lastVisitedAt != $1.lastVisitedAt { return $0.lastVisitedAt > $1.lastVisitedAt }
        if $0.survivedRerank != $1.survivedRerank { return $0.survivedRerank }
        return $0.id < $1.id
    }
}

private func rotated(_ places: [RatedPlace], rotation: Int, limit: Int) -> [RatedPlace] {
    guard places.count > limit else { return places }
    let start = (rotation * limit) % places.count
    return (0..<limit).map { places[(start + $0) % places.count] }
}

/// Counts per stop for the in-track histogram; index 0 is score 1.
public func ratingHistogram(category: PlaceCategory, from rated: [RatedPlace]) -> [Int] {
    var counts = Array(repeating: 0, count: 10)
    for place in rated where place.category == category {
        counts[place.score - 1] += 1
    }
    return counts
}
