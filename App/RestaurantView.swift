import CoreLocation
import Places
import SwiftUI

struct RestaurantView: View {
    let place: PlaceSummary
    @State private var address: String?
    @State private var myScore: Int?
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
                if let myScore {
                    Text("\(myScore)/10").font(.title3.bold())
                } else if loadedRating {
                    Text("Not rated yet").foregroundStyle(.secondary)
                }
                Button(myScore == nil ? "Rate" : "Edit rating") { showRatingFlow = true }
            }
        }
        .navigationTitle(place.name)
        .task { await load() }
        .sheet(isPresented: $showRatingFlow) {
            RatingFlowView(place: place, presetScore: myScore) {
                Task {
                    myScore = try? await RatingService.myRating(placeID: place.id)
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
        myScore = try? await RatingService.myRating(placeID: place.id)
        photos = (try? await PhotoService.photos(placeID: place.id)) ?? []
        loadedRating = true
    }
}
