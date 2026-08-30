import CryptoKit
import Foundation
import Media
import Supabase

enum PhotoService {
    private struct PhotoInsert: Encodable {
        let id: UUID
        let visit_id: UUID
        let storage_path: String
        let tier_sizes: [String: [Int]]
        let source_hash: String
        let position: Int
    }

    struct PlacePhoto: Decodable, Identifiable, Hashable {
        let id: UUID
        let storage_path: String
    }

    /// Whether the photo was uploaded or skipped as a duplicate of one already
    /// on the visit.
    enum AttachResult { case uploaded, duplicate }

    /// Processes one source image into the three tiers off the main actor,
    /// uploads them, and records the photo row. The same source attached to
    /// the same visit twice is skipped by content hash.
    static func attach(imageData: Data, visitID: UUID, position: Int = 0) async throws -> AttachResult {
        let hash = SHA256.hash(data: imageData).map { String(format: "%02x", $0) }.joined()
        struct Existing: Decodable { let id: UUID }
        let existing: [Existing] = try await Supa.client.from("photos")
            .select("id")
            .eq("visit_id", value: visitID)
            .eq("source_hash", value: hash)
            .limit(1).execute().value
        if !existing.isEmpty { return .duplicate }
        let tiers = try await Task.detached(priority: .userInitiated) {
            try processPhoto(imageData)
        }.value
        let photoID = UUID()
        let base = ImagePath.base(visitID: visitID, photoID: photoID)
        for photo in tiers {
            try await Supa.client.storage.from("photos").upload(
                ImagePath.tier(base, photo.tier),
                data: photo.data,
                options: FileOptions(contentType: "image/heic")
            )
        }
        let sizes = Dictionary(uniqueKeysWithValues: tiers.map { ($0.tier.rawValue, [$0.pixelWidth, $0.pixelHeight]) })
        try await Supa.client.from("photos")
            .insert(PhotoInsert(id: photoID, visit_id: visitID, storage_path: base, tier_sizes: sizes, source_hash: hash, position: position))
            .execute()
        return .uploaded
    }

    /// Photos visible to me at a place (mine + accepted friends', via RLS):
    /// newest visit's batch first, selection order within a visit.
    static func photos(placeID: Int64) async throws -> [PlacePhoto] {
        _ = try await Supa.signInIfNeeded()
        struct Row: Decodable {
            let id: UUID
            let storage_path: String
            let visit_id: UUID
            let position: Int
            let created_at: Date
        }
        let rows: [Row] = try await Supa.client.from("photos")
            .select("id, storage_path, visit_id, position, created_at, visits!inner(place_id)")
            .eq("visits.place_id", value: Int(placeID))
            .execute().value
        let newestPerVisit = Dictionary(grouping: rows, by: \.visit_id)
            .mapValues { group in group.map(\.created_at).max()! }
        return rows.sorted {
            let leftBatch = newestPerVisit[$0.visit_id]!
            let rightBatch = newestPerVisit[$1.visit_id]!
            if leftBatch != rightBatch { return leftBatch > rightBatch }
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.created_at < $1.created_at
        }.map { PlacePhoto(id: $0.id, storage_path: $0.storage_path) }
    }

    /// Photos already on one visit, in display order.
    static func visitPhotos(visitID: UUID) async throws -> [PlacePhoto] {
        struct Row: Decodable {
            let id: UUID
            let storage_path: String
            let position: Int
            let created_at: Date
        }
        let rows: [Row] = try await Supa.client.from("photos")
            .select("id, storage_path, position, created_at")
            .eq("visit_id", value: visitID)
            .execute().value
        return rows.sorted {
            $0.position != $1.position ? $0.position < $1.position : $0.created_at < $1.created_at
        }.map { PlacePhoto(id: $0.id, storage_path: $0.storage_path) }
    }

    /// Deletes one photo: all three tier objects, then the row.
    static func deletePhoto(_ photo: PlacePhoto) async throws {
        _ = try await Supa.client.storage.from("photos")
            .remove(paths: PhotoTier.allCases.map { ImagePath.tier(photo.storage_path, $0) })
        try await Supa.client.from("photos").delete().eq("id", value: photo.id).execute()
    }

    /// The only place a storage path becomes a display URL (CLAUDE.md Images):
    /// signed, tier-specific, one hour.
    static func url(for basePath: String, tier: PhotoTier) async throws -> URL {
        try await Supa.client.storage.from("photos")
            .createSignedURL(path: ImagePath.tier(basePath, tier), expiresIn: 3600)
    }
}
