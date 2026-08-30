import Foundation
import Places
import Rating
import Supabase

enum RatingService {
    private struct VisitJoin: Decodable {
        struct RatingRow: Decodable { let score: Int }
        struct PlaceJoin: Decodable { let name: String; let category: String }
        let place_id: Int64
        let visited_at: Date
        let ratings: RatingRow?
        let places: PlaceJoin
    }

    /// Everything the user has rated, aggregated per place for band-mate
    /// selection (latest score, visit count, last visit).
    static func myRatedPlaces() async throws -> [RatedPlace] {
        let uid = try await Supa.signInIfNeeded()
        let rows: [VisitJoin] = try await Supa.client.from("visits")
            .select("place_id, visited_at, ratings(score), places(name, category)")
            .eq("user_id", value: uid)
            .execute().value
        return Dictionary(grouping: rows, by: \.place_id).compactMap { placeID, visits in
            let ratedVisits = visits.filter { $0.ratings != nil }.sorted { $0.visited_at > $1.visited_at }
            guard let latest = ratedVisits.first, let rating = latest.ratings else { return nil }
            return RatedPlace(
                id: placeID,
                name: latest.places.name,
                category: PlaceCategory(rawValue: latest.places.category) ?? .restaurant,
                score: rating.score,
                visitCount: ratedVisits.count,
                lastVisitedAt: latest.visited_at
            )
        }
    }

    private struct VisitInsert: Encodable {
        let user_id: UUID
        let place_id: Int64
        let visited_at: Date
        let source: String
    }
    private struct VisitRow: Decodable { let id: UUID }
    private struct RatingInsert: Encodable {
        let visit_id: UUID
        let score: Int
        let category: String
    }

    /// Writes a new visit + rating; returns the visit id for dish tagging.
    static func saveRating(placeID: Int64, score: Int, category: PlaceCategory) async throws -> UUID {
        let uid = try await Supa.signInIfNeeded()
        let visit: VisitRow = try await Supa.client.from("visits")
            .insert(VisitInsert(user_id: uid, place_id: placeID, visited_at: Date(), source: "manual"))
            .select("id").single().execute().value
        try await Supa.client.from("ratings")
            .insert(RatingInsert(visit_id: visit.id, score: score, category: category.rawValue))
            .execute()
        return visit.id
    }

    private struct RatingUpdate: Encodable {
        let score: Int
        let category: String
    }

    static func updateRating(visitID: UUID, score: Int, category: PlaceCategory) async throws {
        try await Supa.client.from("ratings")
            .update(RatingUpdate(score: score, category: category.rawValue))
            .eq("visit_id", value: visitID)
            .execute()
    }

    /// My rating history at one place, for standing + revisit preset.
    static func myVisits(placeID: Int64) async throws -> [(score: Int, date: Date)] {
        let uid = try await Supa.signInIfNeeded()
        struct Row: Decodable {
            struct RatingRow: Decodable { let score: Int }
            let visited_at: Date
            let ratings: RatingRow?
        }
        let rows: [Row] = try await Supa.client.from("visits")
            .select("visited_at, ratings(score)")
            .eq("place_id", value: Int(placeID))
            .eq("user_id", value: uid)
            .order("visited_at", ascending: false)
            .execute().value
        return rows.compactMap { row in row.ratings.map { (score: $0.score, date: row.visited_at) } }
    }

    /// Existing dish names at this place (all users), for autocomplete.
    static func dishNames(placeID: Int64) async throws -> [String] {
        struct Row: Decodable { let dish_name: String }
        let rows: [Row] = try await Supa.client.from("dish_ratings")
            .select("dish_name, visits!inner(place_id)")
            .eq("visits.place_id", value: Int(placeID))
            .execute().value
        var seen = Set<String>()
        return rows.map(\.dish_name).filter { seen.insert($0.lowercased()).inserted }
    }

    private struct DishInsert: Encodable {
        let visit_id: UUID
        let dish_name: String
        let verdict: String
    }

    static func saveDish(visitID: UUID, name: String, verdict: String) async throws {
        try await Supa.client.from("dish_ratings")
            .insert(DishInsert(visit_id: visitID, dish_name: name, verdict: verdict))
            .execute()
    }
}
