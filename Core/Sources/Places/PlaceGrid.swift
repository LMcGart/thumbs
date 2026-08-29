import Foundation

/// Grid index over the places table: each row carries its cell coordinates so a
/// radius query becomes an indexed range scan plus a haversine refine.
/// Cell size must match scripts/build-places-db.sh, which computes the same
/// cells when building the database.
public enum PlaceGrid {
    /// ~550 m of latitude per cell — comfortably larger than any match radius,
    /// so a query never needs more than the 3×3 neighborhood.
    public static let cellDegrees = 0.005

    public static func cell(_ degrees: Double) -> Int64 {
        Int64((degrees / cellDegrees).rounded(.down))
    }
}
