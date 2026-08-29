import Foundation
import SQLite3
import Testing
@testable import Places

private let base = Coordinate(latitude: 40.7291, longitude: -73.9965)

private func coord(east: Double = 0, north: Double = 0) -> Coordinate {
    let metersPerDegreeLat = 111_320.0
    let metersPerDegreeLon = metersPerDegreeLat * cos(base.latitude * .pi / 180)
    return Coordinate(
        latitude: base.latitude + north / metersPerDegreeLat,
        longitude: base.longitude + east / metersPerDegreeLon
    )
}

/// Builds a places DB with the same schema as scripts/build-places-db.sh.
private func makeDB(rows: [(name: String, at: Coordinate, category: String)]) throws -> String {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("places-test-\(UUID().uuidString).sqlite").path
    var db: OpaquePointer?
    try #require(sqlite3_open(path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    let schema = """
    CREATE TABLE places (
      gers_id TEXT, name TEXT, lat REAL, lon REAL,
      category TEXT, subtype TEXT, cell_lat INTEGER, cell_lon INTEGER
    );
    CREATE INDEX idx_places_cell ON places(cell_lat, cell_lon);
    """
    try #require(sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK)
    for (index, row) in rows.enumerated() {
        let sql = """
        INSERT INTO places VALUES (
          'gers-\(index)', '\(row.name)', \(row.at.latitude), \(row.at.longitude),
          '\(row.category)', 'subtype-\(index)',
          \(PlaceGrid.cell(row.at.latitude)), \(PlaceGrid.cell(row.at.longitude))
        );
        """
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
    return path
}

@Test func findsPlacesWithinRadiusNearestFirst() throws {
    let path = try makeDB(rows: [
        (name: "Far Bistro", at: coord(east: 60), category: "restaurant"),
        (name: "Near Cafe", at: coord(east: 10), category: "cafe"),
        (name: "Outside Bar", at: coord(east: 200), category: "bar"),
    ])
    let store = try PlaceStore(path: path)
    let results = try store.places(near: base, withinMeters: 75)
    #expect(results.map(\.place.name) == ["Near Cafe", "Far Bistro"])
    #expect(results[0].distanceMeters < 15)
    #expect(results[0].place.category == .cafe)
    #expect(results[0].place.gersID == "gers-1")
}

@Test func findsPlacesAcrossCellBoundaries() throws {
    // A point right at a cell edge with the place in the neighboring cell.
    let edgeLat = (PlaceGrid.cellDegrees * 8_146_000).rounded(.down) * PlaceGrid.cellDegrees
    let center = Coordinate(latitude: edgeLat + 0.0001, longitude: base.longitude)
    let neighbor = Coordinate(latitude: edgeLat - 0.0001, longitude: base.longitude)
    #expect(PlaceGrid.cell(center.latitude) != PlaceGrid.cell(neighbor.latitude))
    let path = try makeDB(rows: [(name: "Edge Case Diner", at: neighbor, category: "restaurant")])
    let store = try PlaceStore(path: path)
    let results = try store.places(near: center, withinMeters: 75)
    #expect(results.map(\.place.name) == ["Edge Case Diner"])
}

@Test func emptyRadiusReturnsNothing() throws {
    let path = try makeDB(rows: [(name: "Lonely Bar", at: coord(east: 500), category: "bar")])
    let store = try PlaceStore(path: path)
    #expect(try store.places(near: base, withinMeters: 75).isEmpty)
}

@Test func missingFileThrows() {
    #expect(throws: PlaceStoreError.self) {
        _ = try PlaceStore(path: "/nonexistent/nope.sqlite")
    }
}
