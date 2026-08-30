import Supabase
import SwiftUI

// Dev-only screen proving the item 4 done-when: anonymous sign-in, a rating
// insert, and RLS visibility (run on two simulators to compare user ids).
struct SupabaseDebugView: View {
    @State private var userID: UUID?
    @State private var log: [String] = []
    @State private var busy = false

    private struct PlaceRow: Decodable { let id: Int64; let name: String }
    private struct VisitInsert: Encodable {
        let user_id: UUID
        let place_id: Int64
        let visited_at: Date
        let source: String
    }
    private struct VisitRow: Decodable { let id: UUID }
    private struct RatingInsert: Encodable {
        let user_id: UUID
        let place_id: Int64
        let score: Int
        let category: String
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    Text(userID.map { "user \($0.uuidString.lowercased())" } ?? "signed out")
                        .font(.caption.monospaced())
                    Button("Sign in anonymously") { run { try await signIn() } }
                }
                Section("Item 4 checks") {
                    Button("Insert test visit + rating") { run { try await insertTestRating() } }
                    Button("Count ratings visible to me") { run { try await countVisible() } }
                }
                Section("Item 6 checks") {
                    Button("Seed 30 test ratings") { run { try await seedThirtyRatings() } }
                }
                Section("Item 10 checks") {
                    Button("Reset onboarding (relaunch app)") {
                        UserDefaults.standard.set(false, forKey: "onboardingComplete")
                        log.append("onboarding reset — relaunch to see it")
                    }
                }
                Section("Item 8 checks") {
                    Button("Seed feed friend (200 visits)") { run { try await seedFeedFriend() } }
                    Button("Unfriend feed bots") { run { try await unfriendFeedBots() } }
                }
                Section("Log") {
                    ForEach(log.indices.reversed(), id: \.self) { Text(log[$0]).font(.caption.monospaced()) }
                }
            }
            .navigationTitle("Supabase")
        }
        .disabled(busy)
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            busy = true
            defer { busy = false }
            do { try await work() } catch { log.append("error: \(error)") }
        }
    }

    private func signIn() async throws {
        userID = try await Supa.signInIfNeeded()
        log.append("signed in")
    }

    private func insertTestRating() async throws {
        let uid = try await Supa.signInIfNeeded()
        userID = uid
        let places: [PlaceRow] = try await Supa.client.from("places")
            .select("id,name").limit(1).execute().value
        guard let place = places.first else {
            log.append("no places — run the seed first")
            return
        }
        let visit: VisitRow = try await Supa.client.from("visits")
            .insert(VisitInsert(user_id: uid, place_id: place.id, visited_at: Date(), source: "manual"))
            .select("id").single().execute().value
        try await Supa.client.from("ratings")
            .upsert(RatingInsert(user_id: uid, place_id: place.id, score: 7, category: "restaurant"), onConflict: "user_id,place_id")
            .execute()
        log.append("rated \(place.name) → visit \(visit.id.uuidString.prefix(8))")
    }

    private func seedThirtyRatings() async throws {
        let uid = try await Supa.signInIfNeeded()
        userID = uid
        struct SeedPlace: Decodable { let id: Int64; let category: String }
        let places: [SeedPlace] = try await Supa.client.from("places")
            .select("id,category").limit(30).execute().value
        let scores = [7, 4, 8, 6, 9, 7, 5, 8, 7, 6, 9, 3, 8, 7, 10, 6, 8, 5, 7, 9, 8, 6, 7, 8, 4, 9, 7, 6, 8, 7]
        for (index, seedPlace) in places.enumerated() {
            let visitedAt = Date().addingTimeInterval(-Double.random(in: 1...300) * 86_400)
            _ = try await Supa.client.from("visits")
                .insert(VisitInsert(user_id: uid, place_id: seedPlace.id, visited_at: visitedAt, source: "manual"))
                .execute()
            try await Supa.client.from("ratings")
                .upsert(RatingInsert(user_id: uid, place_id: seedPlace.id, score: scores[index], category: seedPlace.category), onConflict: "user_id,place_id")
                .execute()
        }
        log.append("seeded \(places.count) ratings")
    }

    /// Creates a second anonymous user with 200 rated visits and an accepted
    /// friendship with the current user — feed content plus the 200-row
    /// scroll-smoothness check, without needing a second device.
    private func seedFeedFriend() async throws {
        let uid = try await Supa.signInIfNeeded()
        userID = uid
        if try await hasFeedBotFriend() {
            log.append("a feed bot is already your friend — unfriend it first to reseed")
            return
        }
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let baseURL = URL(string: urlString),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        else { throw URLError(.badURL) }

        func rest(_ path: String, method: String, token: String, json: Any) async throws {
            var request = URLRequest(url: baseURL.appending(path: path))
            request.httpMethod = method
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "seed", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "request failed",
                ])
            }
        }

        // New anonymous user B.
        var signup = URLRequest(url: baseURL.appending(path: "auth/v1/signup"))
        signup.httpMethod = "POST"
        signup.setValue(anonKey, forHTTPHeaderField: "apikey")
        signup.setValue("application/json", forHTTPHeaderField: "Content-Type")
        signup.httpBody = Data("{}".utf8)
        let (signupData, _) = try await URLSession.shared.data(for: signup)
        guard let payload = try JSONSerialization.jsonObject(with: signupData) as? [String: Any],
              let tokenB = payload["access_token"] as? String,
              let userB = (payload["user"] as? [String: Any])?["id"] as? String
        else { throw URLError(.cannotParseResponse) }

        let suffix = String(UUID().uuidString.prefix(4)).lowercased()
        try await rest("rest/v1/profiles?id=eq.\(userB)", method: "PATCH", token: tokenB,
                       json: ["handle": "feedbot_\(suffix)", "display_name": "Feed Bot"])

        // Friendship: current user requests, B accepts.
        try await Supa.client.from("friendships")
            .insert(FriendRequestInsert(requester: uid, addressee: UUID(uuidString: userB)!, status: "requested"))
            .execute()
        try await rest("rest/v1/friendships?requester=eq.\(uid.uuidString)&addressee=eq.\(userB)",
                       method: "PATCH", token: tokenB, json: ["status": "accepted"])

        // 200 visits + ratings for B, spread over the last year.
        struct SeedPlace: Decodable { let id: Int64; let category: String }
        let places: [SeedPlace] = try await Supa.client.from("places")
            .select("id,category").limit(200).execute().value
        let formatter = ISO8601DateFormatter()
        let visits: [[String: Any]] = places.enumerated().map { index, place in
            [
                "user_id": userB,
                "place_id": place.id,
                "visited_at": formatter.string(from: Date().addingTimeInterval(-Double(index) * 40_000 - Double.random(in: 0...30_000))),
                "source": "manual",
            ]
        }
        try await rest("rest/v1/visits", method: "POST", token: tokenB, json: visits)
        let ratings: [[String: Any]] = places.enumerated().map { index, place in
            [
                "user_id": userB,
                "place_id": place.id,
                "score": [4, 5, 6, 6, 7, 7, 7, 8, 8, 9][index % 10],
                "category": place.category,
            ]
        }
        try await rest("rest/v1/ratings?on_conflict=user_id,place_id", method: "POST", token: tokenB, json: ratings)
        log.append("feedbot_\(suffix) friended you with \(places.count) visits — check Home")
    }

    private struct FriendRequestInsert: Encodable {
        let requester: UUID
        let addressee: UUID
        let status: String
    }

    private func feedBotIDs() async throws -> [UUID] {
        let uid = try await Supa.signInIfNeeded()
        let rows = try await SocialService.friendships()
        let others = rows.map { $0.requester == uid ? $0.addressee : $0.requester }
        let profiles = try await SocialService.profiles(ids: others)
        return profiles.filter { $0.handle?.hasPrefix("feedbot_") == true }.map(\.id)
    }

    private func hasFeedBotFriend() async throws -> Bool {
        try await !feedBotIDs().isEmpty
    }

    /// Removes friendships with seeded bots; RLS then hides their visits.
    private func unfriendFeedBots() async throws {
        let uid = try await Supa.signInIfNeeded()
        let bots = try await feedBotIDs()
        for bot in bots {
            try await Supa.client.from("friendships").delete()
                .eq("requester", value: uid).eq("addressee", value: bot).execute()
            try await Supa.client.from("friendships").delete()
                .eq("requester", value: bot).eq("addressee", value: uid).execute()
        }
        log.append("unfriended \(bots.count) feed bot\(bots.count == 1 ? "" : "s")")
    }

    private func countVisible() async throws {
        _ = try await Supa.signInIfNeeded()
        let count = try await Supa.client.from("ratings")
            .select("id", head: true, count: .exact).execute().count
        log.append("visible ratings: \(count ?? -1)")
    }
}
