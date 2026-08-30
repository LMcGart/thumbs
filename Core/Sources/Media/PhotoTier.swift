import CoreGraphics
import Foundation

/// The three upload tiers (CLAUDE.md Images). Dimensions and quality are set
/// here and nowhere else; no tier squeezes to a byte target.
public enum PhotoTier: String, CaseIterable, Sendable {
    case thumb
    case display
    case full

    /// Longest-edge pixel budget.
    public var maxEdge: CGFloat {
        switch self {
        case .thumb: 480
        case .display: 1600
        case .full: 2560
        }
    }

    public var quality: Double {
        switch self {
        case .thumb, .display: 0.8
        case .full: 0.85
        }
    }
}

/// Bucket-relative paths; the DB stores the base, tiers derive from it.
/// Nothing else constructs storage paths.
public enum ImagePath {
    public static func base(visitID: UUID, photoID: UUID) -> String {
        "visits/\(visitID.uuidString.lowercased())/\(photoID.uuidString.lowercased())"
    }

    public static func tier(_ base: String, _ tier: PhotoTier) -> String {
        "\(base)/\(tier.rawValue).heic"
    }
}
