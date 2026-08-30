import Foundation
import ImageIO

/// The moment a photo was taken, from its EXIF metadata (DateTimeOriginal).
/// Used to autofill the visit date; nil when the source carries no capture
/// time. EXIF stores local wall-clock time with no zone, so the current zone
/// is assumed — right for "when did I eat here" purposes.
public func captureDate(from data: Data) -> Date? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
          let stamp = exif[kCGImagePropertyExifDateTimeOriginal] as? String
    else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    return formatter.date(from: stamp)
}
