import Foundation
import Supabase

/// App-wide Supabase client. Config flows Config.xcconfig → Info.plist, so no
/// secrets live in code or git.
enum Supa {
    static let client: SupabaseClient = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: urlString),
              let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        else { fatalError("Copy Example.xcconfig to Config.xcconfig and fill in the Supabase values") }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    /// Dev auth: an anonymous session, created on first use and restored after.
    static func signInIfNeeded() async throws -> UUID {
        if let session = try? await client.auth.session { return session.user.id }
        let session = try await client.auth.signInAnonymously()
        return session.user.id
    }
}
