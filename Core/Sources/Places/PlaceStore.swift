import Foundation
import SQLite3

public struct PlaceStoreError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}

/// Read-only access to the spike POI database built by scripts/build-places-db.sh.
/// Not Sendable: use from a single isolation domain.
public final class PlaceStore {
    private let db: OpaquePointer
    private let candidatesStatement: OpaquePointer

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let handle else {
            let detail = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            throw PlaceStoreError(message: "Cannot open places DB at \(path): \(detail)")
        }
        let sql = """
        SELECT rowid, gers_id, name, lat, lon, category, subtype, confidence
        FROM places
        WHERE cell_lat BETWEEN ? AND ? AND cell_lon BETWEEN ? AND ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let detail = String(cString: sqlite3_errmsg(handle))
            sqlite3_close(handle)
            throw PlaceStoreError(message: "Cannot prepare candidates query: \(detail)")
        }
        self.db = handle
        self.candidatesStatement = statement
    }

    deinit {
        sqlite3_finalize(candidatesStatement)
        sqlite3_close(db)
    }

    /// Places within `radiusMeters` of `center`, nearest first.
    public func places(near center: Coordinate, withinMeters radiusMeters: Double) throws -> [NearbyPlace] {
        // Cell range covering the radius; ±1 cell at the default sizes.
        let latDelta = radiusMeters / 111_320.0
        let lonDelta = latDelta / max(cos(center.latitude * .pi / 180), 0.01)
        sqlite3_reset(candidatesStatement)
        sqlite3_bind_int64(candidatesStatement, 1, PlaceGrid.cell(center.latitude - latDelta))
        sqlite3_bind_int64(candidatesStatement, 2, PlaceGrid.cell(center.latitude + latDelta))
        sqlite3_bind_int64(candidatesStatement, 3, PlaceGrid.cell(center.longitude - lonDelta))
        sqlite3_bind_int64(candidatesStatement, 4, PlaceGrid.cell(center.longitude + lonDelta))

        var results: [NearbyPlace] = []
        while true {
            let step = sqlite3_step(candidatesStatement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else {
                throw PlaceStoreError(message: "Candidates query failed: \(String(cString: sqlite3_errmsg(db)))")
            }
            let coordinate = Coordinate(
                latitude: sqlite3_column_double(candidatesStatement, 3),
                longitude: sqlite3_column_double(candidatesStatement, 4)
            )
            let distance = center.distance(to: coordinate)
            guard distance <= radiusMeters else { continue }
            let place = Place(
                id: sqlite3_column_int64(candidatesStatement, 0),
                gersID: text(column: 1) ?? "",
                name: text(column: 2) ?? "",
                coordinate: coordinate,
                category: text(column: 5).flatMap(PlaceCategory.init(rawValue:)) ?? .restaurant,
                subtype: text(column: 6),
                confidence: sqlite3_column_type(candidatesStatement, 7) == SQLITE_NULL
                    ? 0.5 : sqlite3_column_double(candidatesStatement, 7)
            )
            results.append(NearbyPlace(place: place, distanceMeters: distance))
        }
        return results.sorted { $0.distanceMeters < $1.distanceMeters }
    }

    private func text(column: Int32) -> String? {
        sqlite3_column_text(candidatesStatement, column).map { String(cString: $0) }
    }
}
