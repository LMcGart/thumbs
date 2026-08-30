import Media
import SwiftUI

/// Grid of visit photos at thumb tier. Structurally list-safe: this view can
/// only ever request `thumb` — feeds and grids have no path to `full`.
struct PhotoGridView: View {
    let photos: [PhotoService.PlacePhoto]
    @State private var selected: PhotoService.PlacePhoto?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
            ForEach(photos) { photo in
                TierImage(basePath: photo.storage_path, tier: .thumb)
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture { selected = photo }
            }
        }
        .sheet(item: $selected) { PhotoDetailView(photo: $0) }
    }
}

/// Detail view: display tier on open; `full` only after the user zooms in.
struct PhotoDetailView: View {
    let photo: PhotoService.PlacePhoto
    @State private var tier: PhotoTier = .display
    @State private var zoom: CGFloat = 1

    var body: some View {
        TierImage(basePath: photo.storage_path, tier: tier)
            .scaleEffect(zoom)
            .gesture(
                MagnificationGesture()
                    .onChanged { zoom = $0 }
                    .onEnded { value in
                        if value > 1.2 { tier = .full }  // lazy full on zoom in
                        withAnimation { zoom = 1 }
                    }
            )
            .presentationDragIndicator(.visible)
    }
}

/// Resolves a signed URL for one tier and renders it.
struct TierImage: View {
    let basePath: String
    let tier: PhotoTier
    @State private var url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
        .task(id: tier) { url = try? await PhotoService.url(for: basePath, tier: tier) }
    }
}
