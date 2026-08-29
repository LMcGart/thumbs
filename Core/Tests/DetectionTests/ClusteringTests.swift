import Foundation
import Places
import Testing
@testable import Detection

private let base = Coordinate(latitude: 40.7291, longitude: -73.9965)

/// A coordinate offset from `origin` by meters east/north.
private func coord(east: Double = 0, north: Double = 0, from origin: Coordinate = base) -> Coordinate {
    let metersPerDegreeLat = 111_320.0
    let metersPerDegreeLon = metersPerDegreeLat * cos(origin.latitude * .pi / 180)
    return Coordinate(
        latitude: origin.latitude + north / metersPerDegreeLat,
        longitude: origin.longitude + east / metersPerDegreeLon
    )
}

private func sample(_ id: String, minutes: Double, location: Coordinate?) -> PhotoSample {
    PhotoSample(id: id, date: Date(timeIntervalSinceReferenceDate: minutes * 60), location: location)
}

@Test func photosCloseInTimeAndSpaceCluster() {
    let clusters = clusterPhotos([
        sample("a", minutes: 0, location: coord()),
        sample("b", minutes: 30, location: coord(east: 20)),
    ])
    #expect(clusters.count == 1)
    #expect(clusters[0].photos.map(\.id) == ["a", "b"])
}

@Test func photosThreeHoursApartDoNotCluster() {
    let clusters = clusterPhotos([
        sample("a", minutes: 0, location: coord()),
        sample("b", minutes: 180, location: coord()),
    ])
    #expect(clusters.count == 2)
}

@Test func photos200MetersApartDoNotCluster() {
    let clusters = clusterPhotos([
        sample("a", minutes: 0, location: coord()),
        sample("b", minutes: 10, location: coord(east: 200)),
    ])
    #expect(clusters.count == 2)
}

@Test func photoWithoutLocationIsDropped() {
    let clusters = clusterPhotos([
        sample("a", minutes: 0, location: coord()),
        sample("b", minutes: 5, location: nil),
    ])
    #expect(clusters.count == 1)
    #expect(clusters[0].photos.map(\.id) == ["a"])
}

@Test func fiftyPhotosAcrossFourVisitsProduceFourClusters() {
    let counts = [12, 13, 12, 13]
    var samples: [PhotoSample] = []
    for (visit, count) in counts.enumerated() {
        let origin = coord(east: Double(visit) * 5_000)  // visits 5 km apart
        let startMinutes = Double(visit) * 480           // and 8 h apart
        for i in 0..<count {
            samples.append(sample(
                "v\(visit)p\(i)",
                minutes: startMinutes + Double(i) * 4,   // a photo every 4 min
                location: coord(east: Double(i % 4) * 8, north: Double(i % 3) * 7, from: origin)
            ))
        }
    }
    #expect(samples.count == 50)
    let clusters = clusterPhotos(samples)
    #expect(clusters.count == 4)
    #expect(clusters.map(\.photos.count) == counts)
}

@Test func clusterReportsCentroidStartAndEndAndSortsUnsortedInput() {
    let early = sample("early", minutes: 0, location: coord())
    let late = sample("late", minutes: 10, location: coord(east: 30))
    let clusters = clusterPhotos([late, early])  // deliberately out of order
    #expect(clusters.count == 1)
    #expect(clusters[0].photos.map(\.id) == ["early", "late"])
    #expect(clusters[0].start == early.date)
    #expect(clusters[0].end == late.date)
    #expect(clusters[0].centroid.distance(to: coord(east: 15)) < 1)
}

@Test func centroidIsRobustToOneWildGPSPoint() {
    let clusters = clusterPhotos([
        sample("a", minutes: 0, location: coord()),
        sample("b", minutes: 5, location: coord(east: 2)),
        sample("c", minutes: 10, location: coord(east: 4)),
        sample("d", minutes: 15, location: coord(east: 40)),  // GPS outlier, still in-cluster
    ])
    #expect(clusters.count == 1)
    // Median lands at 3 m east; a mean would be dragged to 11.5 m.
    #expect(clusters[0].centroid.distance(to: coord(east: 3)) < 1)
}

@Test func emptyInputProducesNoClusters() {
    #expect(clusterPhotos([]).isEmpty)
}

@Test func customThresholdsAreRespected() {
    let clusters = clusterPhotos(
        [
            sample("a", minutes: 0, location: coord()),
            sample("b", minutes: 30, location: coord(east: 20)),
        ],
        maxTimeGap: 10 * 60,
        maxDistanceMeters: 10
    )
    #expect(clusters.count == 2)
}
