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
        let visit_id: UUID
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
            .insert(RatingInsert(visit_id: visit.id, score: 7, category: "restaurant"))
            .execute()
        log.append("rated \(place.name) → visit \(visit.id.uuidString.prefix(8))")
    }

    private func countVisible() async throws {
        _ = try await Supa.signInIfNeeded()
        let count = try await Supa.client.from("ratings")
            .select("id", head: true, count: .exact).execute().count
        log.append("visible ratings: \(count ?? -1)")
    }
}
