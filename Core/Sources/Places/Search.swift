import Foundation

/// A server search hit (a row we own).
public struct PlaceSummary: Sendable, Identifiable, Hashable {
    public let id: Int64
    public let name: String
    public let category: PlaceCategory
    public let subtype: String?
    public let address: String?
    public let coordinate: Coordinate
    public let distanceMeters: Double?

    public init(id: Int64, name: String, category: PlaceCategory, subtype: String?, address: String?, coordinate: Coordinate, distanceMeters: Double?) {
        self.id = id
        self.name = name
        self.category = category
        self.subtype = subtype
        self.address = address
        self.coordinate = coordinate
        self.distanceMeters = distanceMeters
    }
}

/// An Apple Maps result not yet in our table.
public struct AppleCandidate: Sendable, Identifiable, Hashable {
    public let mapKitID: String?
    public let name: String
    public let category: PlaceCategory
    public let address: String?
    public let coordinate: Coordinate

    public var id: String { mapKitID ?? "\(name)@\(coordinate.latitude),\(coordinate.longitude)" }

    public init(mapKitID: String?, name: String, category: PlaceCategory, address: String?, coordinate: Coordinate) {
        self.mapKitID = mapKitID
        self.name = name
        self.category = category
        self.address = address
        self.coordinate = coordinate
    }
}

public enum SearchHit: Sendable, Identifiable, Hashable {
    case place(PlaceSummary)
    case apple(AppleCandidate)

    public var id: String {
        switch self {
        case .place(let place): "place-\(place.id)"
        case .apple(let candidate): "apple-\(candidate.id)"
        }
    }
}

/// Blends Apple results into server results. Duplicates collapse in two
/// passes: server rows against each other first (Overture carries
/// near-duplicate rows for one storefront), then Apple results against the
/// surviving server rows. Server rows always win — they carry our IDs and
/// everyone's rating history; the radius keeps same-name places in other
/// cities (chains) distinct. Order is preserved, so the nearest of a
/// duplicate pair survives.
public func blendSearchResults(
    server: [PlaceSummary],
    apple: [AppleCandidate],
    duplicateRadiusMeters: Double = 150
) -> [SearchHit] {
    var deduped: [PlaceSummary] = []
    for row in server {
        let duplicate = deduped.contains { kept in
            placeNamesLikelyMatch(kept.name, row.name)
                && kept.coordinate.distance(to: row.coordinate) <= duplicateRadiusMeters
        }
        if !duplicate { deduped.append(row) }
    }
    let server = deduped
    var hits: [SearchHit] = server.map { .place($0) }
    for candidate in apple {
        let duplicate = server.contains { row in
            placeNamesLikelyMatch(row.name, candidate.name)
                && row.coordinate.distance(to: candidate.coordinate) <= duplicateRadiusMeters
        }
        if !duplicate { hits.append(.apple(candidate)) }
    }
    return hits
}
