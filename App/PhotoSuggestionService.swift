import CoreLocation
import Foundation
import Photos

struct PhotoSuggestion: Sendable, Identifiable {
    let id: String
    let image: CGImage
}

/// Finds library photos taken near a coordinate — the "you were here, want
/// these?" strip in the rating flow. Declining photo access just means no
/// suggestions; the manual picker never needs this permission.
enum PhotoSuggestionService {
    static func suggestions(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 120,
        limit: Int = 12
    ) async -> [PhotoSuggestion] {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let target = CLLocation(latitude: latitude, longitude: longitude)
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            // Location is not predicate-queryable; scan recent assets and
            // filter by distance, capped so a huge library stays fast.
            options.fetchLimit = 2000
            let assets = PHAsset.fetchAssets(with: .image, options: options)
            var results: [PhotoSuggestion] = []
            assets.enumerateObjects { asset, _, stop in
                guard let location = asset.location,
                      location.distance(from: target) <= radiusMeters
                else { return }
                if let image = loadThumb(asset) {
                    results.append(PhotoSuggestion(id: asset.localIdentifier, image: image))
                }
                if results.count >= limit { stop.pointee = true }
            }
            return results
        }.value
    }

    /// Original bytes for one suggestion, for the tier pipeline + hash dedupe.
    static func imageData(assetID: String) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
                return nil
            }
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true
            var data: Data?
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { result, _, _, _ in
                data = result
            }
            return data
        }.value
    }

    private static func loadThumb(_ asset: PHAsset) -> CGImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        var thumb: CGImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 240, height: 240),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            thumb = image?.cgImage
        }
        return thumb
    }
}
