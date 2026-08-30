import Foundation
import Media
import Supabase

enum PhotoService {
    private struct PhotoInsert: Encodable {
        let id: UUID
        let visit_id: UUID
        let storage_path: String
        let tier_sizes: [String: [Int]]
    }

    struct PlacePhoto: Decodable, Identifiable, Hashable {
        let id: UUID
        let storage_path: String
    }

    /// Processes one source image into the three tiers off the main actor,
    /// uploads them, and records the photo row.
    static func attach(imageData: Data, visitID: UUID) async throws {
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
            .insert(PhotoInsert(id: photoID, visit_id: visitID, storage_path: base, tier_sizes: sizes))
            .execute()
    }

    /// Photos visible to me at a place (mine + accepted friends', via RLS).
    static func photos(placeID: Int64) async throws -> [PlacePhoto] {
        _ = try await Supa.signInIfNeeded()
        struct Row: Decodable {
            let id: UUID
            let storage_path: String
        }
        let rows: [Row] = try await Supa.client.from("photos")
            .select("id, storage_path, visits!inner(place_id)")
            .eq("visits.place_id", value: Int(placeID))
            .order("created_at", ascending: false)
            .execute().value
        return rows.map { PlacePhoto(id: $0.id, storage_path: $0.storage_path) }
    }

    /// The only place a storage path becomes a display URL (CLAUDE.md Images):
    /// signed, tier-specific, one hour.
    static func url(for basePath: String, tier: PhotoTier) async throws -> URL {
        try await Supa.client.storage.from("photos")
            .createSignedURL(path: ImagePath.tier(basePath, tier), expiresIn: 3600)
    }
}
