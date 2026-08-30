import CoreLocation
import Places
import Rating
import SwiftUI

struct RestaurantView: View {
    let place: PlaceSummary
    @State private var address: String?
    @State private var myVisits: [(score: Int, date: Date)] = []
    @State private var loadedRating = false
    @State private var showRatingFlow = false
    @State private var photos: [PhotoService.PlacePhoto] = []

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
            if !photos.isEmpty {
                Section("Photos") {
                    PhotoGridView(photos: photos)
                }
            }
            Section("Your rating") {
                if !myVisits.isEmpty {
                    let value = standing(for: myVisits)
                    Text(myVisits.count == 1
                         ? "\(myVisits[0].score)/10"
                         : String(format: "%.1f/10 · %d visits", value, myVisits.count))
                        .font(.title3.bold())
                } else if loadedRating {
                    Text("Not rated yet").foregroundStyle(.secondary)
                }
                Button(myVisits.isEmpty ? "Rate" : "Rate again") { showRatingFlow = true }
            }
        }
        .navigationTitle(place.name)
        .task { await load() }
        .sheet(isPresented: $showRatingFlow) {
            RatingFlowView(place: place, presetScore: myVisits.first?.score) {
                Task {
                    myVisits = (try? await RatingService.myVisits(placeID: place.id)) ?? []
                    photos = (try? await PhotoService.photos(placeID: place.id)) ?? []
                }
            }
        }
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
        myVisits = (try? await RatingService.myVisits(placeID: place.id)) ?? []
        photos = (try? await PhotoService.photos(placeID: place.id)) ?? []
        loadedRating = true
    }
}
