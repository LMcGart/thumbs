import CoreGraphics
import Foundation
import ImageIO

public struct ProcessedPhoto: Sendable {
    public let tier: PhotoTier
    public let data: Data
    public let pixelWidth: Int
    public let pixelHeight: Int
}

public struct PhotoProcessingError: Error, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}

/// Any library source format → the three HEIC tiers. Decodes to pixels once
/// per tier via ImageIO downsampling; re-encoding from pixels drops every
/// metadata field, including GPS — location lives on the visit record, never
/// in the file. Images smaller than a tier's edge are never upscaled.
public func processPhoto(_ data: Data) throws -> [ProcessedPhoto] {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) > 0
    else { throw PhotoProcessingError("Unreadable image data") }

    return try PhotoTier.allCases.map { tier in
        guard let image = downsampled(source, maxEdge: tier.maxEdge) else {
            throw PhotoProcessingError("Could not decode source for \(tier.rawValue)")
        }
        let encoded = try encodeHEIC(image, quality: tier.quality)
        return ProcessedPhoto(tier: tier, data: encoded, pixelWidth: image.width, pixelHeight: image.height)
    }
}

/// One decoded, orientation-corrected image capped to `maxEdge` — also used
/// for staged-photo previews before upload.
public func downsampledImage(from data: Data, maxEdge: CGFloat) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return downsampled(source, maxEdge: maxEdge)
}

private func downsampled(_ source: CGImageSource, maxEdge: CGFloat) -> CGImage? {
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxEdge,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}

private func encodeHEIC(_ image: CGImage, quality: Double) throws -> Data {
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, "public.heic" as CFString, 1, nil) else {
        throw PhotoProcessingError("HEIC encoding unavailable")
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw PhotoProcessingError("HEIC encode failed")
    }
    return output as Data
}
