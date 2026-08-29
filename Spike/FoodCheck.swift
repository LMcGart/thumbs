import AppKit
import CoreGraphics
import Foundation
import Photos
import Vision

/// Whether the photo looks like food, via Vision's multi-label classifier.
/// Umbrella identifiers only; the threshold is a starting value to tune at the
/// gate alongside the clustering thresholds.
private let foodIdentifiers: Set<String> = ["food", "meal", "dessert", "beverage", "drink"]
private let foodConfidenceThreshold: Float = 0.4

func photoLooksLikeFood(assetID: String) async -> Bool {
    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject,
          let cgImage = await loadCGImage(asset)
    else { return false }
    let request = ClassifyImageRequest()
    guard let observations = try? await request.perform(on: cgImage) else { return false }
    return observations.contains { foodIdentifiers.contains($0.identifier) && $0.confidence >= foodConfidenceThreshold }
}

/// Small target size: enough for classification, avoids pulling originals from iCloud.
private func loadCGImage(_ asset: PHAsset) async -> CGImage? {
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat  // exactly one callback
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false
    return await withCheckedContinuation { continuation in
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 512, height: 512),
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
            var rect = CGRect(origin: .zero, size: image?.size ?? .zero)
            continuation.resume(returning: image?.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        }
    }
}
