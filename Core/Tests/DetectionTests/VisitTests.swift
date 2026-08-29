import Foundation
import Places
import Testing
@testable import Detection

private func cluster(photoCount: Int) -> Cluster {
    let center = Coordinate(latitude: 40.7291, longitude: -73.9965)
    let photos = (0..<photoCount).map {
        PhotoSample(id: "p\($0)", date: Date(timeIntervalSinceReferenceDate: Double($0) * 60), location: center)
    }
    return Cluster(photos: photos, centroid: center, start: photos.first!.date, end: photos.last!.date)
}

private func candidate(_ name: String, distance: Double) -> NearbyPlace {
    NearbyPlace(
        place: Place(
            id: 1, gersID: "g", name: name,
            coordinate: Coordinate(latitude: 0, longitude: 0),
            category: .restaurant, subtype: nil
        ),
        distanceMeters: distance
    )
}

@Test func singleCandidateWithTwoPhotosAndFoodIsHigh() {
    let visit = DetectedVisit(cluster: cluster(photoCount: 2), candidates: [candidate("Lupa", distance: 20)], foodPhotoFound: true)
    #expect(visit.confidence == .high)
}

@Test func singleCandidateWithoutFoodIsLow() {
    let visit = DetectedVisit(cluster: cluster(photoCount: 3), candidates: [candidate("Lupa", distance: 20)], foodPhotoFound: false)
    #expect(visit.confidence == .low)
}

@Test func singleCandidateWithOnePhotoIsLow() {
    let visit = DetectedVisit(cluster: cluster(photoCount: 1), candidates: [candidate("Lupa", distance: 20)], foodPhotoFound: true)
    #expect(visit.confidence == .low)
}

@Test func multipleCandidatesAreAmbiguousEvenWithFood() {
    let visit = DetectedVisit(
        cluster: cluster(photoCount: 4),
        candidates: [candidate("Lupa", distance: 20), candidate("Minetta Tavern", distance: 40)],
        foodPhotoFound: true
    )
    #expect(visit.confidence == .ambiguous)
}

@Test func singlePhotoWithoutFoodIsLowEvenWithManyCandidates() {
    let visit = DetectedVisit(
        cluster: cluster(photoCount: 1),
        candidates: [candidate("Lupa", distance: 20), candidate("Minetta Tavern", distance: 40)],
        foodPhotoFound: false
    )
    #expect(visit.confidence == .low)
}

@Test func singlePhotoWithFoodAndManyCandidatesStaysAmbiguous() {
    let visit = DetectedVisit(
        cluster: cluster(photoCount: 1),
        candidates: [candidate("Lupa", distance: 20), candidate("Minetta Tavern", distance: 40)],
        foodPhotoFound: true
    )
    #expect(visit.confidence == .ambiguous)
}

@Test func noCandidatesIsLow() {
    let visit = DetectedVisit(cluster: cluster(photoCount: 5), candidates: [], foodPhotoFound: true)
    #expect(visit.confidence == .low)
}
