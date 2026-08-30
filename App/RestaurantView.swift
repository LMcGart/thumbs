import CoreLocation
import Places
import SwiftUI

struct RestaurantView: View {
    let place: PlaceSummary
    @State private var address: String?
    @State private var myRating: RatingService.MyRating?
    @State private var loadedRating = false
    @State private var showRatingFlow = false
    @State private var photos: [PhotoService.PlacePhoto] = []
    private var uploads: PendingPhotoUploads { .shared }

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
            if !photos.isEmpty || !uploads.pending(for: place.id).isEmpty {
                Section("Photos") {
                    PhotoGridView(photos: photos, pending: uploads.pending(for: place.id))
                }
            }
            Section("Your rating") {
                if let myRating {
                    Text("\(myRating.score)/10").font(.title3.bold())
                } else if loadedRating {
                    Text("Not rated yet").foregroundStyle(.secondary)
                }
                Button(myRating == nil ? "Rate" : "Edit rating") { showRatingFlow = true }
            }
        }
        .navigationTitle(place.name)
        .task { await load() }
        .onChange(of: uploads.pending(for: place.id).count) { previous, current in
            // An upload just landed; pull the server copy into the grid.
            if current < previous {
                Task { photos = (try? await PhotoService.photos(placeID: place.id)) ?? [] }
            }
        }
        .sheet(isPresented: $showRatingFlow, onDismiss: {
            Task {
                myRating = try? await RatingService.myRating(placeID: place.id)
                photos = (try? await PhotoService.photos(placeID: place.id)) ?? []
            }
        }) {
            RatingFlowView(place: place, preset: myRating) {}
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
        myRating = try? await RatingService.myRating(placeID: place.id)
        photos = (try? await PhotoService.photos(placeID: place.id)) ?? []
        loadedRating = true
    }
}
