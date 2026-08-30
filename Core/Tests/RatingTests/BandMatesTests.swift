import Foundation
import Places
import Testing
@testable import Rating

private func day(_ offset: Int) -> Date { Date(timeIntervalSinceReferenceDate: Double(offset) * 86_400) }

private func rated(_ id: Int64, _ name: String, score: Int, visits: Int = 1, last: Int = 0, category: PlaceCategory = .restaurant) -> RatedPlace {
    RatedPlace(id: id, name: name, category: category, score: score, visitCount: visits, lastVisitedAt: day(last))
}

@Test func bandShowsPlacesAtThatScoreOnly() {
    let mates = bandMates(at: 7, category: .restaurant, from: [
        rated(1, "Seven A", score: 7), rated(2, "Eight", score: 8), rated(3, "Seven B", score: 7),
    ])
    #expect(mates.emptyLabel == nil)
    #expect(mates.groups.count == 1)
    #expect(Set(mates.groups[0].places.map(\.name)) == ["Seven A", "Seven B"])
}

@Test func priorityIsVisitsThenRecency() {
    let mates = bandMates(at: 7, category: .restaurant, from: [
        rated(1, "Once, recent", score: 7, visits: 1, last: 100),
        rated(2, "Thrice, old", score: 7, visits: 3, last: 1),
        rated(3, "Twice, recent", score: 7, visits: 2, last: 90),
        rated(4, "Twice, old", score: 7, visits: 2, last: 10),
    ])
    #expect(mates.groups[0].places.map(\.name) == ["Thrice, old", "Twice, recent", "Twice, old"])
}

@Test func rotationCyclesThroughTheBandWithoutRepeating() {
    let band = (1...5).map { rated(Int64($0), "P\($0)", score: 7, visits: 6 - $0) }
    let first = bandMates(at: 7, category: .restaurant, from: band, rotation: 0).groups[0].places.map(\.name)
    let second = bandMates(at: 7, category: .restaurant, from: band, rotation: 1).groups[0].places.map(\.name)
    let third = bandMates(at: 7, category: .restaurant, from: band, rotation: 2).groups[0].places.map(\.name)
    #expect(first == ["P1", "P2", "P3"])
    #expect(second == ["P4", "P5", "P1"])
    #expect(third == ["P2", "P3", "P4"])
}

@Test func emptyBandFallsBackToNearestAboveAndBelow() {
    let mates = bandMates(at: 8, category: .restaurant, from: [
        rated(1, "Nine", score: 9), rated(2, "Six", score: 6), rated(3, "Ten", score: 10),
    ])
    #expect(mates.emptyLabel == "no 8s yet")
    #expect(mates.groups.map(\.label) == ["your 9s", "your 6s"])
    #expect(mates.groups[0].places.map(\.name) == ["Nine"])
    #expect(mates.groups[1].places.map(\.name) == ["Six"])
}

@Test func bandMatesComeFromTheSameCategoryOnly() {
    let mates = bandMates(at: 7, category: .cafe, from: [
        rated(1, "Restaurant Seven", score: 7, category: .restaurant),
        rated(2, "Cafe Seven", score: 7, category: .cafe),
    ])
    #expect(mates.groups[0].places.map(\.name) == ["Cafe Seven"])
}

@Test func fewerThanLimitShowsWhatExists() {
    let mates = bandMates(at: 3, category: .bar, from: [rated(1, "Dive", score: 3, category: .bar)])
    #expect(mates.groups[0].places.count == 1)
}

@Test func histogramCountsPerStopWithinCategory() {
    let counts = ratingHistogram(category: .restaurant, from: [
        rated(1, "A", score: 7), rated(2, "B", score: 7), rated(3, "C", score: 2),
        rated(4, "Cafe", score: 7, category: .cafe),
    ])
    #expect(counts[6] == 2)
    #expect(counts[1] == 1)
    #expect(counts.reduce(0, +) == 3)
}
