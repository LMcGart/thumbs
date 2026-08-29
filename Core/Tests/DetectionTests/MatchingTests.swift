import Foundation
import Places
import Testing
@testable import Detection

private func candidate(_ name: String, distance: Double, confidence: Double = 1.0) -> NearbyPlace {
    NearbyPlace(
        place: Place(
            id: Int64(name.hashValue & 0xFFFF), gersID: "g-\(name)", name: name,
            coordinate: Coordinate(latitude: 40.7, longitude: -74.0),
            category: .restaurant, subtype: nil, confidence: confidence
        ),
        distanceMeters: distance
    )
}

@Test func nameDuplicatesCollapseKeepingBetterRanked() {
    let ranked = rankCandidates([
        candidate("Maman Nyc", distance: 21),
        candidate("Maman", distance: 13),
        candidate("Cafe Kitsune Inc.", distance: 21),
        candidate("Cafe Kitsune", distance: 25),
    ])
    #expect(ranked.map(\.place.name) == ["Maman", "Cafe Kitsune Inc."])
}

@Test func confidenceBreaksNearTies() {
    let ranked = rankCandidates([
        candidate("Junk Row", distance: 20, confidence: 0.3),
        candidate("Solid Storefront", distance: 25, confidence: 1.0),
    ])
    #expect(ranked.map(\.place.name) == ["Solid Storefront", "Junk Row"])
}

@Test func confidenceDoesNotOverrideClearDistanceGaps() {
    let ranked = rankCandidates([
        candidate("Right Here", distance: 5, confidence: 0.5),
        candidate("Down The Block", distance: 60, confidence: 1.0),
    ])
    #expect(ranked.map(\.place.name) == ["Right Here", "Down The Block"])
}

@Test func shortAndDistinctNamesAreNotDeduped() {
    let ranked = rankCandidates([
        candidate("Bar", distance: 10),
        candidate("Barbuto", distance: 12),
        candidate("Lupa", distance: 15),
    ])
    #expect(ranked.count == 3)
}
