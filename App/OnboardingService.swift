import Detection
import Foundation
import Places
import Supabase

/// A detected recent place for calibration: one card per distinct place,
/// most recent first, with switchable alternatives when ambiguous.
struct DetectedPlace: Identifiable, Sendable {
    let id: UUID
    let visitedAt: Date
    let photoCount: Int
    let candidates: [(place: PlaceSummary, distanceMeters: Double)]
    var chosen: Int = 0

    var chosenPlace: PlaceSummary { candidates[chosen].place }
}

enum OnboardingService {
    private struct NearbyRow: Decodable {
        let id: Int64
        let name: String
        let category: String
        let subtype: String?
        let address: String?
        let lat: Double
        let lon: Double
        let distance_meters: Double
        let confidence: Double?
    }

    private struct NearbyParams: Encodable {
        let near_lat: Double
        let near_lon: Double
    }

    /// The user's last `limit` distinct places from photo metadata — sure-tier
    /// only (product decision 2026-08-29): a card must have exactly one
    /// candidate after dedupe, at least two photos, and a meal signal. No
    /// disambiguation is ever shown; fewer correct cards beat more doubtful
    /// ones. Returns [] when access is declined or nothing qualifies.
    @MainActor
    static func recentPlaces(limit: Int = 10, lookbackDays: Int = 180) async -> [DetectedPlace] {
        guard let samples = try? await fetchPhotoSamples(days: lookbackDays) else { return [] }
        let clusters = clusterPhotos(samples)
        let (kept, _) = partitionFrequentLocations(clusters)
        var results: [DetectedPlace] = []
        var seenPlaces: Set<Int64> = []
        // Cap the walk so a candidate-sparse library can't stall onboarding.
        for cluster in kept.sorted(by: { $0.start > $1.start }).prefix(60) {
            guard results.count < limit else { break }
            guard let rows: [NearbyRow] = try? await Supa.client
                .rpc("nearby_places", params: NearbyParams(near_lat: cluster.centroid.latitude, near_lon: cluster.centroid.longitude))
                .execute().value, !rows.isEmpty
            else { continue }
            let ranked = rankCandidates(rows.map { row in
                NearbyPlace(
                    place: Place(
                        id: row.id, gersID: "", name: row.name,
                        coordinate: Coordinate(latitude: row.lat, longitude: row.lon),
                        category: PlaceCategory(rawValue: row.category) ?? .restaurant,
                        subtype: row.subtype, confidence: row.confidence ?? 0.5
                    ),
                    distanceMeters: row.distance_meters
                )
            })
            guard ranked.count == 1, cluster.photos.count >= 2 else { continue }
            let summaries = ranked.prefix(3).map { candidate in
                (
                    place: PlaceSummary(
                        id: candidate.place.id, name: candidate.place.name,
                        category: candidate.place.category, subtype: candidate.place.subtype,
                        address: nil, coordinate: candidate.place.coordinate,
                        distanceMeters: candidate.distanceMeters
                    ),
                    distanceMeters: candidate.distanceMeters
                )
            }
            guard let top = summaries.first, !seenPlaces.contains(top.place.id) else { continue }
            guard await looksLikeMeal(cluster) else { continue }
            seenPlaces.insert(top.place.id)
            results.append(DetectedPlace(
                id: UUID(),
                visitedAt: cluster.start,
                photoCount: cluster.photos.count,
                candidates: Array(summaries)
            ))
        }
        return results
    }

    /// Meal signal on the middle photo, falling back to the first — the same
    /// classifier and 0.3 threshold the spike tuned.
    private static func looksLikeMeal(_ cluster: Cluster) async -> Bool {
        var tried: Set<String> = []
        for photo in [cluster.photos[cluster.photos.count / 2], cluster.photos[0]] {
            guard tried.insert(photo.id).inserted else { continue }
            if case .classified(let score, _, _) = await checkFood(assetID: photo.id), score >= 0.3 {
                return true
            }
        }
        return false
    }
}
