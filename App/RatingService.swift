import Foundation
import Places
import Rating
import Supabase

enum RatingService {
    private struct RatingJoin: Decodable {
        struct PlaceJoin: Decodable { let name: String; let category: String }
        let place_id: Int64
        let score: Int
        let updated_at: Date
        let places: PlaceJoin
    }

    /// Everything the user has rated, one row per place, with visit counts
    /// from the activity log for band-mate priority.
    static func myRatedPlaces() async throws -> [RatedPlace] {
        let uid = try await Supa.signInIfNeeded()
        let ratings: [RatingJoin] = try await Supa.client.from("ratings")
            .select("place_id, score, updated_at, places(name, category)")
            .eq("user_id", value: uid)
            .execute().value
        struct VisitStub: Decodable { let place_id: Int64; let visited_at: Date }
        let visits: [VisitStub] = try await Supa.client.from("visits")
            .select("place_id, visited_at")
            .eq("user_id", value: uid)
            .execute().value
        let visitsByPlace = Dictionary(grouping: visits, by: \.place_id)
        return ratings.map { rating in
            let placeVisits = visitsByPlace[rating.place_id] ?? []
            return RatedPlace(
                id: rating.place_id,
                name: rating.places.name,
                category: PlaceCategory(rawValue: rating.places.category) ?? .restaurant,
                score: rating.score,
                visitCount: max(placeVisits.count, 1),
                lastVisitedAt: placeVisits.map(\.visited_at).max() ?? rating.updated_at
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
    private struct RatingUpsert: Encodable {
        let user_id: UUID
        let place_id: Int64
        let score: Int
        let category: String
        let updated_at: Date
    }

    /// Upserts the user's one rating for the place, ensures a visit exists as
    /// the activity-log entry (created only if none), and returns that visit's
    /// id so photos and dishes have somewhere to attach.
    static func saveRating(placeID: Int64, score: Int, category: PlaceCategory) async throws -> UUID {
        let uid = try await Supa.signInIfNeeded()
        try await Supa.client.from("ratings")
            .upsert(
                RatingUpsert(user_id: uid, place_id: placeID, score: score, category: category.rawValue, updated_at: Date()),
                onConflict: "user_id,place_id"
            )
            .execute()
        let existing: [VisitRow] = try await Supa.client.from("visits")
            .select("id")
            .eq("place_id", value: Int(placeID))
            .eq("user_id", value: uid)
            .order("visited_at", ascending: false)
            .limit(1).execute().value
        if let visit = existing.first { return visit.id }
        let visit: VisitRow = try await Supa.client.from("visits")
            .insert(VisitInsert(user_id: uid, place_id: placeID, visited_at: Date(), source: "manual"))
            .select("id").single().execute().value
        return visit.id
    }

    /// Deletes the user's rating for the place, and the auto-created
    /// activity-log visit too when nothing (photos, dishes) hangs off it.
    static func removeRating(placeID: Int64) async throws {
        let uid = try await Supa.signInIfNeeded()
        try await Supa.client.from("ratings").delete()
            .eq("user_id", value: uid)
            .eq("place_id", value: Int(placeID))
            .execute()
        let visits: [VisitRow] = try await Supa.client.from("visits")
            .select("id")
            .eq("user_id", value: uid)
            .eq("place_id", value: Int(placeID))
            .order("visited_at", ascending: false)
            .limit(1).execute().value
        guard let visit = visits.first else { return }
        struct Stub: Decodable { let id: UUID }
        let photos: [Stub] = try await Supa.client.from("photos")
            .select("id").eq("visit_id", value: visit.id).limit(1).execute().value
        let dishes: [Stub] = try await Supa.client.from("dish_ratings")
            .select("id").eq("visit_id", value: visit.id).limit(1).execute().value
        if photos.isEmpty && dishes.isEmpty {
            try await Supa.client.from("visits").delete().eq("id", value: visit.id).execute()
        }
    }

    /// The user's rating for this place, if any.
    static func myRating(placeID: Int64) async throws -> Int? {
        let uid = try await Supa.signInIfNeeded()
        struct Row: Decodable { let score: Int }
        let rows: [Row] = try await Supa.client.from("ratings")
            .select("score")
            .eq("place_id", value: Int(placeID))
            .eq("user_id", value: uid)
            .limit(1).execute().value
        return rows.first?.score
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
