import AppKit
import CoreGraphics
import Foundation
import Photos
import Vision

/// Meal-scene identifiers from Vision's taxonomy; the score is the max over
/// these. Tableware-family labels are included deliberately: on the small
/// thumbnails available from an iCloud-optimized library, table scenes score
/// tableware/plate far higher than the "food" umbrella itself, and a set table
/// is exactly the visit signal we want. Home-table false positives are largely
/// absorbed by the frequent-location exclusion.
private let foodIdentifiers: Set<String> = [
    "food", "meal", "dessert", "beverage", "drink",
    "tableware", "utensil", "plate", "cup", "drinking_glass",
]

enum FoodCheckResult {
    case classified(foodScore: Float, width: Int, top: [String])
    case assetMissing
    case imageUnavailable(String)
    case visionFailed(String)
}

func checkFood(assetID: String) async -> FoodCheckResult {
    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
        return .assetMissing
    }
    let cgImage: CGImage
    switch await loadCGImage(asset) {
    case .success(let image): cgImage = image
    case .failure(let message): return .imageUnavailable(message)
    }
    let request = ClassifyImageRequest()
    do {
        let observations = try await request.perform(on: cgImage)
        let foodScore = observations
            .filter { foodIdentifiers.contains($0.identifier) }
            .map(\.confidence)
            .max() ?? 0
        let top = observations.sorted { $0.confidence > $1.confidence }.prefix(5)
            .map { "\($0.identifier) \(String(format: "%.2f", $0.confidence))" }
        return .classified(foodScore: Float(foodScore), width: cgImage.width, top: top)
    } catch {
        return .visionFailed(String(describing: error))
    }
}

private enum ImageLoad {
    case success(CGImage)
    case failure(String)
}

/// High-quality 512px first (real resolution when the derivative is local);
/// with an iCloud-optimized library that fetch can fail from a CLI context
/// (CloudPhotoLibraryError 1005), so fall back to the always-local thumbnail.
private func loadCGImage(_ asset: PHAsset) async -> ImageLoad {
    switch await requestImage(asset, deliveryMode: .highQualityFormat) {
    case .success(let image): return .success(image)
    case .failure: return await requestImage(asset, deliveryMode: .fastFormat)
    }
}

private func requestImage(_ asset: PHAsset, deliveryMode: PHImageRequestOptionsDeliveryMode) async -> ImageLoad {
    let options = PHImageRequestOptions()
    options.deliveryMode = deliveryMode
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = true
    // Synchronous is the recommended mode for batch processing; the async path
    // returned nil images from this CLI context.
    options.isSynchronous = true
    return await Task.detached {
        var result = ImageLoad.failure("handler never ran")
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 512, height: 512),
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            guard let image else {
                let infoText = info.map { String(describing: $0) } ?? "no info"
                result = .failure("Photos returned no image; info: \(infoText)")
                return
            }
            var rect = CGRect(origin: .zero, size: image.size)
            if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                result = .success(cgImage)
            } else if let bitmap = image.representations.compactMap({ ($0 as? NSBitmapImageRep)?.cgImage }).first {
                result = .success(bitmap)
            } else {
                result = .failure("NSImage not convertible to CGImage")
            }
        }
        return result
    }.value
}
