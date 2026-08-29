import Foundation
import Places
import Testing
@testable import Detection

private func cluster(day: Int, at location: Coordinate, hour: Int = 12) -> Cluster {
    var components = DateComponents()
    components.year = 2026; components.month = 1; components.day = 1 + day; components.hour = hour
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let photo = PhotoSample(id: "d\(day)h\(hour)", date: date, location: location)
    return Cluster(photos: [photo], centroid: location, start: date, end: date)
}

private let home = Coordinate(latitude: 40.7000, longitude: -73.9500)
private let restaurant = Coordinate(latitude: 40.7291, longitude: -73.9965)

@Test func locationRecurringOnEnoughDaysIsExcluded() {
    let clusters = (0..<6).map { cluster(day: $0, at: home) } + [cluster(day: 2, at: restaurant)]
    let (kept, excluded) = partitionFrequentLocations(clusters, minDistinctDays: 5)
    #expect(excluded.count == 6)
    #expect(kept.map(\.centroid) == [restaurant])
}

@Test func manyClustersOnOneDayAreKept() {
    let clusters = (0..<6).map { cluster(day: 0, at: home, hour: 8 + $0 * 2) }
    let (kept, excluded) = partitionFrequentLocations(clusters, minDistinctDays: 5)
    #expect(kept.count == 6)
    #expect(excluded.isEmpty)
}

@Test func fewerRecurrencesThanThresholdAreKept() {
    let clusters = (0..<4).map { cluster(day: $0 * 7, at: restaurant) }
    let (kept, excluded) = partitionFrequentLocations(clusters, minDistinctDays: 5)
    #expect(kept.count == 4)
    #expect(excluded.isEmpty)
}
