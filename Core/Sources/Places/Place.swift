import Foundation

/// The three review categories. Every place maps to exactly one; the original
/// Overture subtype is kept as metadata.
public enum PlaceCategory: String, Sendable, Codable, CaseIterable {
    case restaurant
    case cafe
    case bar
}

public struct Place: Sendable, Hashable, Identifiable {
    /// Our own ID (SQLite rowid in the spike DB). Never a third-party ID.
    public let id: Int64
    /// Overture GERS ID, kept as a secondary column for future syncs.
    public let gersID: String
    public let name: String
    public let coordinate: Coordinate
    public let category: PlaceCategory
    public let subtype: String?

    public init(id: Int64, gersID: String, name: String, coordinate: Coordinate, category: PlaceCategory, subtype: String?) {
        self.id = id
        self.gersID = gersID
        self.name = name
        self.coordinate = coordinate
        self.category = category
        self.subtype = subtype
    }
}

public struct NearbyPlace: Sendable {
    public let place: Place
    public let distanceMeters: Double

    public init(place: Place, distanceMeters: Double) {
        self.place = place
        self.distanceMeters = distanceMeters
    }
}
