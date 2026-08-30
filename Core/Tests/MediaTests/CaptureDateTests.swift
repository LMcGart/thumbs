import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Media

private func imageData(exifDate: String?) throws -> Data {
    let context = CGContext(
        data: nil, width: 40, height: 30, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil)!
    var properties: [CFString: Any] = [:]
    if let exifDate {
        properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: exifDate]
    }
    CGImageDestinationAddImage(destination, context.makeImage()!, properties as CFDictionary)
    try #require(CGImageDestinationFinalize(destination))
    return output as Data
}

@Test func readsExifCaptureDate() throws {
    let date = captureDate(from: try imageData(exifDate: "2026:03:14 19:41:20"))
    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: try #require(date))
    #expect(components.year == 2026 && components.month == 3 && components.day == 14)
    #expect(components.hour == 19 && components.minute == 41)
}

@Test func missingExifYieldsNil() throws {
    #expect(captureDate(from: try imageData(exifDate: nil)) == nil)
}
