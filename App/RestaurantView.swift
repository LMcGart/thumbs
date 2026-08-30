import CoreLocation
import Places
import SwiftUI

struct RestaurantView: View {
    let place: PlaceSummary
    @State private var address: String?
    @State private var myScore: Int?
    @State private var loadedRating = false

    var body: some View {
        List {
            Section {
                Text(place.category.rawValue.capitalized)
                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                if let address {
                    Text(address).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section("Your rating") {
                if let myScore {
                    Text("\(myScore)/10").font(.title3.bold())
                } else if loadedRating {
                    Text("Not rated yet").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(place.name)
        .task { await load() }
    }

    private struct VisitRow: Decodable {
        struct Rating: Decodable { let score: Int }
        let ratings: Rating?
    }

    private func load() async {
        address = place.address
        if address == nil {
            let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            if let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
                address = [mark.subThoroughfare, mark.thoroughfare, mark.locality]
                    .compactMap { $0 }.joined(separator: " ")
            }
        }
        if let uid = try? await Supa.signInIfNeeded() {
            let visits: [VisitRow] = (try? await Supa.client.from("visits")
                .select("ratings(score)")
                .eq("place_id", value: Int(place.id))
                .eq("user_id", value: uid)
                .order("visited_at", ascending: false)
                .limit(10).execute().value) ?? []
            myScore = visits.compactMap(\.ratings?.score).first
        }
        loadedRating = true
    }
}
