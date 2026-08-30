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

    /// One reverse-chronological page of visits: accepted friends' by default
    /// (own excluded), or a single user's when `userID` is given — the same
    /// query powers the feed and the profile's own-review list.
    static func page(before: Date?, limit: Int = 20, userID: UUID? = nil) async throws -> [Entry] {
        let uid = try await Supa.signInIfNeeded()
        var query = Supa.client.from("visits")
            .select("id, user_id, place_id, visited_at, places(name, category), profiles(id, handle, display_name, avatar_path), photos(id, storage_path, position)")
        if let userID {
            query = query.eq("user_id", value: userID)
        } else {
            query = query.neq("user_id", value: uid)
        }
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
        let parent_id: UUID?
        let profiles: SocialService.Profile
    }

    static func comments(visitID: UUID) async throws -> [Comment] {
        _ = try await Supa.signInIfNeeded()
        return try await Supa.client.from("comments")
            .select("id, user_id, body, created_at, parent_id, profiles(id, handle, display_name, avatar_path)")
            .eq("visit_id", value: visitID)
            .order("created_at", ascending: true)
            .execute().value
    }

    private struct CommentInsert: Encodable {
        let visit_id: UUID
        let user_id: UUID
        let body: String
        let parent_id: UUID?
    }

    static func addComment(visitID: UUID, body: String, parentID: UUID? = nil) async throws {
        let uid = try await Supa.signInIfNeeded()
        try await Supa.client.from("comments")
            .insert(CommentInsert(visit_id: visitID, user_id: uid, body: body, parent_id: parentID))
            .execute()
    }

    static func deleteComment(id: UUID) async throws {
        try await Supa.client.from("comments").delete().eq("id", value: id).execute()
    }

    /// Depth-first thread order for rendering: each comment paired with its
    /// nesting depth, children under parents, oldest first at every level.
    static func threaded(_ comments: [Comment]) -> [(comment: Comment, depth: Int)] {
        let children = Dictionary(grouping: comments.filter { $0.parent_id != nil }, by: { $0.parent_id! })
        var result: [(comment: Comment, depth: Int)] = []
        func walk(_ comment: Comment, depth: Int) {
            result.append((comment, depth))
            for child in (children[comment.id] ?? []).sorted(by: { $0.created_at < $1.created_at }) {
                walk(child, depth: depth + 1)
            }
        }
        for root in comments.filter({ $0.parent_id == nil }).sorted(by: { $0.created_at < $1.created_at }) {
            walk(root, depth: 0)
        }
        return result
    }

    struct LikeState: Sendable {
        var count: Int
        var liked: Bool
    }

    private struct LikeRow: Decodable {
        let user_id: UUID
        let visit_id: UUID?
        let comment_id: UUID?
    }

    /// Like counts + my-like flags for a set of visits.
    static func visitLikes(visitIDs: [UUID]) async throws -> [UUID: LikeState] {
        guard !visitIDs.isEmpty else { return [:] }
        let uid = try await Supa.signInIfNeeded()
        let rows: [LikeRow] = try await Supa.client.from("likes")
            .select("user_id, visit_id, comment_id")
            .in("visit_id", values: visitIDs)
            .execute().value
        return aggregate(rows, key: \.visit_id, me: uid)
    }

    /// Like counts + my-like flags for a set of comments.
    static func commentLikes(commentIDs: [UUID]) async throws -> [UUID: LikeState] {
        guard !commentIDs.isEmpty else { return [:] }
        let uid = try await Supa.signInIfNeeded()
        let rows: [LikeRow] = try await Supa.client.from("likes")
            .select("user_id, visit_id, comment_id")
            .in("comment_id", values: commentIDs)
            .execute().value
        return aggregate(rows, key: \.comment_id, me: uid)
    }

    private static func aggregate(_ rows: [LikeRow], key: KeyPath<LikeRow, UUID?>, me: UUID) -> [UUID: LikeState] {
        var result: [UUID: LikeState] = [:]
        for row in rows {
            guard let target = row[keyPath: key] else { continue }
            var state = result[target] ?? LikeState(count: 0, liked: false)
            state.count += 1
            if row.user_id == me { state.liked = true }
            result[target] = state
        }
        return result
    }

    private struct VisitLikeInsert: Encodable { let user_id: UUID; let visit_id: UUID }
    private struct CommentLikeInsert: Encodable { let user_id: UUID; let comment_id: UUID }

    static func setVisitLike(visitID: UUID, liked: Bool) async throws {
        let uid = try await Supa.signInIfNeeded()
        if liked {
            try await Supa.client.from("likes")
                .insert(VisitLikeInsert(user_id: uid, visit_id: visitID)).execute()
        } else {
            try await Supa.client.from("likes").delete()
                .eq("user_id", value: uid).eq("visit_id", value: visitID).execute()
        }
    }

    static func setCommentLike(commentID: UUID, liked: Bool) async throws {
        let uid = try await Supa.signInIfNeeded()
        if liked {
            try await Supa.client.from("likes")
                .insert(CommentLikeInsert(user_id: uid, comment_id: commentID)).execute()
        } else {
            try await Supa.client.from("likes").delete()
                .eq("user_id", value: uid).eq("comment_id", value: commentID).execute()
        }
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
