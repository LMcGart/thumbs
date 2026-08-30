import CoreGraphics
import Foundation
import Observation

/// In-flight background photo uploads, visible to the restaurant page so
/// just-attached photos appear immediately as local previews and swap to
/// server images as each upload lands.
@MainActor @Observable
final class PendingPhotoUploads {
    static let shared = PendingPhotoUploads()

    struct Pending: Identifiable {
        let id: String
        let placeID: Int64
        let preview: CGImage?
    }

    private(set) var items: [Pending] = []

    func pending(for placeID: Int64) -> [Pending] {
        items.filter { $0.placeID == placeID }
    }

    func enqueue(photos: [(id: String, data: Data, preview: CGImage?)], placeID: Int64, visitID: UUID) {
        let new = photos.filter { photo in !items.contains { $0.id == photo.id } }
        guard !new.isEmpty else { return }
        items.append(contentsOf: new.map { Pending(id: $0.id, placeID: placeID, preview: $0.preview) })
        let uploads = new.map { (id: $0.id, data: $0.data) }
        Task {
            for (index, upload) in uploads.enumerated() {
                _ = try? await PhotoService.attach(imageData: upload.data, visitID: visitID, position: index)
                items.removeAll { $0.id == upload.id }
            }
        }
    }
}
