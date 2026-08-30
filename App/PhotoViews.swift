import Media
import SwiftUI

/// Grid of visit photos at thumb tier. Structurally list-safe: this view can
/// only ever request `thumb` — feeds and grids have no path to `full`.
private struct PagerStart: Identifiable {
    let index: Int
    var id: Int { index }
}

struct PhotoGridView: View {
    let photos: [PhotoService.PlacePhoto]
    var pending: [PendingPhotoUploads.Pending] = []
    @State private var pagerStart: PagerStart?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
            ForEach(pending) { upload in
                ZStack {
                    if let preview = upload.preview {
                        Image(decorative: preview, scale: 1)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle().fill(.quaternary)
                    }
                    ProgressView()
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(0.75)
            }
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                TierImage(basePath: photo.storage_path, tier: .thumb)
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture { pagerStart = PagerStart(index: index) }
            }
        }
        .sheet(item: $pagerStart) { start in
            PhotoPagerView(photos: photos, startIndex: start.index)
        }
    }
}

/// Swipeable pager over a place's photos; each page opens at display tier and
/// loads `full` only after the user zooms in.
struct PhotoPagerView: View {
    let photos: [PhotoService.PlacePhoto]
    @State private var index: Int

    init(photos: [PhotoService.PlacePhoto], startIndex: Int) {
        self.photos = photos
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { position, photo in
                ZoomableTierImage(photo: photo).tag(position)
            }
        }
        .tabViewStyle(.page)
        .presentationDragIndicator(.visible)
    }
}

private struct ZoomableTierImage: View {
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
