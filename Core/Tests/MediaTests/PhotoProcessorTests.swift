import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Media

/// A synthetic photo of the given size, encoded as `type` (JPEG/HEIC), with
/// GPS metadata attached so the strip behavior is observable.
private func makeImage(width: Int, height: Int, type: String) throws -> Data {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, type as CFString, 1, nil)!
    let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 40.7291, kCGImagePropertyGPSLongitude: 73.9965]
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
    try #require(CGImageDestinationFinalize(destination))
    return output as Data
}

private func assertThreeHEICTiers(_ source: Data) throws {
    let tiers = try processPhoto(source)
    #expect(tiers.map(\.tier) == [.thumb, .display, .full])
    for photo in tiers {
        let decoded = CGImageSourceCreateWithData(photo.data as CFData, nil)!
        #expect(CGImageSourceGetType(decoded) as String? == "public.heic")
        let properties = CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil) as! [CFString: Any]
        #expect(properties[kCGImagePropertyGPSDictionary] == nil, "GPS must be stripped")
        #expect(max(photo.pixelWidth, photo.pixelHeight) <= Int(photo.tier.maxEdge))
    }
    #expect(max(tiers[0].pixelWidth, tiers[0].pixelHeight) == 480)
    #expect(max(tiers[1].pixelWidth, tiers[1].pixelHeight) == 1600)
    #expect(max(tiers[2].pixelWidth, tiers[2].pixelHeight) == 2560)
}

@Test func jpegSourceProducesThreeHEICTiers() throws {
    try assertThreeHEICTiers(try makeImage(width: 4000, height: 3000, type: "public.jpeg"))
}

@Test func heicSourceProducesThreeHEICTiers() throws {
    try assertThreeHEICTiers(try makeImage(width: 4000, height: 3000, type: "public.heic"))
}

@Test func smallSourceIsNeverUpscaled() throws {
    let tiers = try processPhoto(try makeImage(width: 300, height: 200, type: "public.jpeg"))
    for photo in tiers {
        #expect(max(photo.pixelWidth, photo.pixelHeight) <= 300)
    }
}

@Test func garbageDataThrows() {
    #expect(throws: PhotoProcessingError.self) {
        _ = try processPhoto(Data([0x00, 0x01, 0x02]))
    }
}

@Test func tierPathsAreBucketRelative() {
    let visit = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let photo = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    let base = ImagePath.base(visitID: visit, photoID: photo)
    #expect(base == "visits/11111111-2222-3333-4444-555555555555/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
    #expect(ImagePath.tier(base, .display) == base + "/display.heic")
}
