import Foundation
import Places
import Testing
@testable import Detection

private func visit(name: String?, dayOffset: Int, photoCount: Int = 2, food: Bool = true, alternatives: [String] = []) -> DetectedVisit {
    let center = Coordinate(latitude: 40.7291, longitude: -73.9965)
    let start = Date(timeIntervalSinceReferenceDate: Double(dayOffset) * 86_400)
    let photos = (0..<photoCount).map {
        PhotoSample(id: "p\($0)", date: start.addingTimeInterval(Double($0) * 60), location: center)
    }
    let cluster = Cluster(photos: photos, centroid: center, start: start, end: photos.last!.date)
    let names = (name.map { [$0] } ?? []) + alternatives
    let candidates = names.enumerated().map { index, candidateName in
        NearbyPlace(
            place: Place(id: Int64(index), gersID: "g\(index)", name: candidateName, coordinate: center, category: .restaurant, subtype: nil),
            distanceMeters: Double(10 + index * 15)
        )
    }
    return DetectedVisit(cluster: cluster, candidates: candidates, foodPhotoFound: food)
}

@Test func reportSortsRowsByDateAndShowsCandidates() {
    let later = visit(name: "Via Carota", dayOffset: 10)
    let earlier = visit(name: "Lupa", dayOffset: 2, alternatives: ["Minetta Tavern"])
    let report = renderSpikeReport(visits: [later, earlier], excluded: [], windowDays: 365, generatedAt: Date(timeIntervalSinceReferenceDate: 0))
    let lupaRow = report.range(of: "Lupa (10 m)")
    let viaRow = report.range(of: "Via Carota (10 m)")
    #expect(lupaRow != nil && viaRow != nil)
    #expect(lupaRow!.lowerBound < viaRow!.lowerBound)
    #expect(report.contains("Minetta Tavern (25 m)"))
    #expect(report.contains("| ambiguous |"))
    #expect(report.contains("| high |"))
    #expect(report.contains("maps.apple.com"))
}

@Test func reportShowsDashForNoCandidatesAndCountsConfidence() {
    let report = renderSpikeReport(visits: [visit(name: nil, dayOffset: 0)], excluded: [], windowDays: 90, generatedAt: Date(timeIntervalSinceReferenceDate: 0))
    #expect(report.contains("| — | — | low |"))
    #expect(report.contains("Window: last 90 days"))
    #expect(report.contains("low 1"))
    #expect(!report.contains("Excluded frequent locations"))
}

@Test func reportGroupsExcludedClustersByLocation() {
    let home = Coordinate(latitude: 40.7000, longitude: -73.9500)
    let excluded = (0..<6).map { day -> Cluster in
        let date = Date(timeIntervalSinceReferenceDate: Double(day) * 86_400)
        let photo = PhotoSample(id: "h\(day)", date: date, location: home)
        return Cluster(photos: [photo], centroid: home, start: date, end: date)
    }
    let report = renderSpikeReport(visits: [], excluded: excluded, windowDays: 365, generatedAt: Date(timeIntervalSinceReferenceDate: 0))
    #expect(report.contains("Excluded frequent locations"))
    #expect(report.contains("| 6 | 6 |"))  // one grouped row: 6 clusters, 6 days
    #expect(report.contains("6 excluded as frequent locations"))
}
