import Foundation
import Media
import Supabase

enum SocialService {
    struct Profile: Decodable, Identifiable, Hashable, Sendable {
        let id: UUID
        let handle: String?
        let display_name: String?
        let avatar_path: String?

        var shownName: String { display_name ?? handle.map { "@\($0)" } ?? "Someone" }
    }

    static func myProfile() async throws -> Profile {
        let uid = try await Supa.signInIfNeeded()
        return try await Supa.client.from("profiles")
            .select("id, handle, display_name, avatar_path")
            .eq("id", value: uid)
            .single().execute().value
    }

    private struct ProfileUpdate: Encodable {
        let handle: String?
        let display_name: String?
    }

    static func updateProfile(handle: String?, displayName: String?) async throws {
        let uid = try await Supa.signInIfNeeded()
        let normalized = handle?.trimmingCharacters(in: .whitespaces).lowercased()
        try await Supa.client.from("profiles")
            .update(ProfileUpdate(handle: normalized?.isEmpty == true ? nil : normalized,
                                  display_name: displayName?.isEmpty == true ? nil : displayName))
            .eq("id", value: uid)
            .execute()
    }

    private struct AvatarPathUpdate: Encodable { let avatar_path: String }

    /// Avatar = the thumb tier only, at a fixed per-user path.
    static func uploadAvatar(imageData: Data) async throws {
        let uid = try await Supa.signInIfNeeded()
        let processed = try await Task.detached { try processPhoto(imageData) }.value
        guard let thumb = processed.first(where: { $0.tier == .thumb }) else { return }
        let path = "users/\(uid.uuidString.lowercased()).heic"
        try await Supa.client.storage.from("avatars")
            .upload(path, data: thumb.data, options: FileOptions(contentType: "image/heic", upsert: true))
        try await Supa.client.from("profiles")
            .update(AvatarPathUpdate(avatar_path: path))
            .eq("id", value: uid).execute()
    }

    static func avatarURL(path: String) async throws -> URL {
        try await Supa.client.storage.from("avatars").createSignedURL(path: path, expiresIn: 3600)
    }

    static func findProfile(handle: String) async throws -> Profile? {
        let rows: [Profile] = try await Supa.client.from("profiles")
            .select("id, handle, display_name, avatar_path")
            .eq("handle", value: handle.trimmingCharacters(in: .whitespaces).lowercased())
            .limit(1).execute().value
        return rows.first
    }

    struct Friendship: Decodable, Sendable {
        let requester: UUID
        let addressee: UUID
        let status: String
    }

    private struct FriendshipInsert: Encodable {
        let requester: UUID
        let addressee: UUID
        let status: String
    }

    static func sendRequest(to userID: UUID) async throws {
        let uid = try await Supa.signInIfNeeded()
        try await Supa.client.from("friendships")
            .insert(FriendshipInsert(requester: uid, addressee: userID, status: "requested"))
            .execute()
    }

    private struct FriendshipAccept: Encodable { let status: String }

    static func accept(requester: UUID) async throws {
        let uid = try await Supa.signInIfNeeded()
        try await Supa.client.from("friendships")
            .update(FriendshipAccept(status: "accepted"))
            .eq("requester", value: requester)
            .eq("addressee", value: uid)
            .execute()
    }

    static func friendships() async throws -> [Friendship] {
        _ = try await Supa.signInIfNeeded()
        return try await Supa.client.from("friendships")
            .select("requester, addressee, status")
            .execute().value
    }

    static func profiles(ids: [UUID]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        return try await Supa.client.from("profiles")
            .select("id, handle, display_name, avatar_path")
            .in("id", values: ids)
            .execute().value
    }
}
