import Foundation
import Testing
@testable import Places

private let nyc = Coordinate(latitude: 40.7291, longitude: -73.9965)
private let sf = Coordinate(latitude: 37.7660, longitude: -122.4307)

private func serverHit(_ name: String, at location: Coordinate = nyc) -> PlaceSummary {
    PlaceSummary(id: Int64(abs(name.hashValue % 10_000)), name: name, category: .restaurant,
                 subtype: nil, address: nil, coordinate: location, distanceMeters: 100)
}

private func appleHit(_ name: String, at location: Coordinate = nyc) -> AppleCandidate {
    AppleCandidate(mapKitID: "mk-\(name)", name: name, category: .restaurant,
                   address: "123 Test St", coordinate: location)
}

@Test func appleDuplicateOfServerRowIsDropped() {
    let hits = blendSearchResults(
        server: [serverHit("Lupa")],
        apple: [appleHit("Lupa Osteria Romana"), appleHit("Minetta Tavern")]
    )
    #expect(hits.map(\.id) == ["place-\(serverHit("Lupa").id)", "apple-mk-Minetta Tavern"])
}

@Test func sameNameInAnotherCityIsKept() {
    let hits = blendSearchResults(server: [serverHit("Tartine", at: sf)], apple: [appleHit("Tartine", at: nyc)])
    #expect(hits.count == 2)  // a chain: same name, different city
}

@Test func serverRowsComeFirst() {
    let hits = blendSearchResults(server: [serverHit("Via Carota")], apple: [appleHit("Emilio's Ballato")])
    if case .place = hits[0] {} else { Issue.record("server row should lead") }
    #expect(hits.count == 2)
}

@Test func emptyServerResultsPassAppleThrough() {
    let hits = blendSearchResults(server: [], apple: [appleHit("Sukiyabashi Jiro")])
    #expect(hits.count == 1)
}

@Test func serverSideDuplicatesCollapseKeepingTheNearest() {
    let nearer = PlaceSummary(id: 1, name: "Uva Enoteca", category: .restaurant, subtype: nil,
                              address: nil, coordinate: sf, distanceMeters: 40)
    let farther = PlaceSummary(id: 2, name: "Uva Enoteca Llc", category: .restaurant, subtype: nil,
                               address: nil, coordinate: sf, distanceMeters: 90)
    let hits = blendSearchResults(server: [nearer, farther], apple: [])
    #expect(hits.map(\.id) == ["place-1"])
}

@Test func sameNameServerRowsInDifferentCitiesBothSurvive() {
    let sfRow = PlaceSummary(id: 1, name: "Tartine", category: .cafe, subtype: nil,
                             address: nil, coordinate: sf, distanceMeters: 40)
    let nycRow = PlaceSummary(id: 2, name: "Tartine", category: .cafe, subtype: nil,
                              address: nil, coordinate: nyc, distanceMeters: 90)
    #expect(blendSearchResults(server: [sfRow, nycRow], apple: []).count == 2)
}
