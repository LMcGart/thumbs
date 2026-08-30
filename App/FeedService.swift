import Foundation
import Places
import Supabase

enum FeedService {
    struct Entry: Identifiable, Hashable, Sendable {
        let id: UUID
        let user: SocialService.Profile
        let placeID: Int64
        let placeName: String
        let category: PlaceCategory
        let visitedAt: Date
        let score: Int?
        let photos: [PhotoService.PlacePhoto]
    }

    private struct VisitRow: Decodable {
        struct PlaceJoin: Decodable { let name: String; let category: String }
        struct PhotoJoin: Decodable { let id: UUID; let storage_path: String; let position: Int }
        let id: UUID
        let user_id: UUID
        let place_id: Int64
        let visited_at: Date
        let places: PlaceJoin
        let profiles: SocialService.Profile
        let photos: [PhotoJoin]
    }

    private struct RatingRow: Decodable {
        let user_id: UUID
        let place_id: Int64
        let score: Int
    }

    /// One reverse-chronological page of accepted friends' visits (RLS already
    /// limits rows to friends; own visits are excluded here).
    static func page(before: Date?, limit: Int = 20) async throws -> [Entry] {
        let uid = try await Supa.signInIfNeeded()
        var query = Supa.client.from("visits")
            .select("id, user_id, place_id, visited_at, places(name, category), profiles(id, handle, display_name, avatar_path), photos(id, storage_path, position)")
            .neq("user_id", value: uid)
        if let before {
            query = query.lt("visited_at", value: before)
        }
        let rows: [VisitRow] = try await query
            .order("visited_at", ascending: false)
            .limit(limit)
            .execute().value
        guard !rows.isEmpty else { return [] }

        let ratings: [RatingRow] = try await Supa.client.from("ratings")
            .select("user_id, place_id, score")
            .in("user_id", values: Array(Set(rows.map(\.user_id))))
            .in("place_id", values: Array(Set(rows.map { Int($0.place_id) })))
            .execute().value
        let scoreByUserPlace = Dictionary(uniqueKeysWithValues: ratings.map { ("\($0.user_id)-\($0.place_id)", $0.score) })

        return rows.map { row in
            Entry(
                id: row.id,
                user: row.profiles,
                placeID: row.place_id,
                placeName: row.places.name,
                category: PlaceCategory(rawValue: row.places.category) ?? .restaurant,
                visitedAt: row.visited_at,
                score: scoreByUserPlace["\(row.user_id)-\(row.place_id)"],
                photos: row.photos
                    .sorted { $0.position != $1.position ? $0.position < $1.position : $0.id.uuidString < $1.id.uuidString }
                    .map { PhotoService.PlacePhoto(id: $0.id, storage_path: $0.storage_path) }
            )
        }
    }

    struct Comment: Decodable, Identifiable, Hashable, Sendable {
        let id: UUID
        let user_id: UUID
        let body: String
        let created_at: Date
        let profiles: SocialService.Profile
    }

    static func comments(visitID: UUID) async throws -> [Comment] {
        _ = try await Supa.signInIfNeeded()
        return try await Supa.client.from("comments")
            .select("id, user_id, body, created_at, profiles(id, handle, display_name, avatar_path)")
            .eq("visit_id", value: visitID)
            .order("created_at", ascending: true)
            .execute().value
    }

    private struct CommentInsert: Encodable {
        let visit_id: UUID
        let user_id: UUID
        let body: String
    }

    static func addComment(visitID: UUID, body: String) async throws {
        let uid = try await Supa.signInIfNeeded()
        try await Supa.client.from("comments")
            .insert(CommentInsert(visit_id: visitID, user_id: uid, body: body))
            .execute()
    }

    static func deleteComment(id: UUID) async throws {
        try await Supa.client.from("comments").delete().eq("id", value: id).execute()
    }

    /// One place as a PlaceSummary, for navigating from a review to its
    /// restaurant page.
    static func place(id: Int64) async throws -> PlaceSummary {
        struct Row: Decodable {
            let id: Int64
            let name: String
            let category: String
            let subtype: String?
            let address: String?
            let lat: Double
            let lon: Double
        }
        let row: Row = try await Supa.client.from("places")
            .select("id, name, category, subtype, address, lat, lon")
            .eq("id", value: Int(id))
            .single().execute().value
        return PlaceSummary(
            id: row.id, name: row.name,
            category: PlaceCategory(rawValue: row.category) ?? .restaurant,
            subtype: row.subtype, address: row.address,
            coordinate: Coordinate(latitude: row.lat, longitude: row.lon),
            distanceMeters: nil
        )
    }

    /// Dishes on one visit, for the detail view.
    static func dishes(visitID: UUID) async throws -> [(name: String, verdict: String)] {
        struct Row: Decodable { let dish_name: String; let verdict: String }
        let rows: [Row] = try await Supa.client.from("dish_ratings")
            .select("dish_name, verdict")
            .eq("visit_id", value: visitID)
            .execute().value
        return rows.map { ($0.dish_name, $0.verdict) }
    }
}
