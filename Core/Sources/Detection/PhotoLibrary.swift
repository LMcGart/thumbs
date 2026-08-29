import Foundation
import Photos
import Places

/// I/O adapter (not unit-tested): fetches image assets from the last `days`
/// days as PhotoSamples. Screenshots are excluded at fetch; assets without
/// location come through with a nil location and are dropped by clustering.
public func fetchPhotoSamples(days: Int) async throws -> [PhotoSample] {
    // Photos offers no read-only level; .readWrite is the minimum that allows reading.
    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    guard status == .authorized || status == .limited else {
        throw DetectionIOError("Photo library access not granted (status: \(status.rawValue)). Grant access and rerun.")
    }

    let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    let options = PHFetchOptions()
    options.predicate = NSPredicate(
        format: "creationDate >= %@ AND NOT ((mediaSubtypes & %d) != 0)",
        cutoff as NSDate,
        PHAssetMediaSubtype.photoScreenshot.rawValue
    )
    let assets = PHAsset.fetchAssets(with: .image, options: options)

    var samples: [PhotoSample] = []
    assets.enumerateObjects { asset, _, _ in
        guard let date = asset.creationDate else { return }
        let location = asset.location.map {
            Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        samples.append(PhotoSample(id: asset.localIdentifier, date: date, location: location))
    }
    return samples
}

public struct DetectionIOError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}
