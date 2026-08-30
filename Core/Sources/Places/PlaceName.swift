import Foundation

/// "Maman" / "Maman Nyc" / "Cafe Kitsune Inc." are the same place: lowercase,
/// strip punctuation and filler tokens, then compare with whole-name prefixes.
/// Shared by detection candidate dedupe and search-result blending so there is
/// exactly one definition of "these names mean the same place".
public func placeNamesLikelyMatch(_ a: String, _ b: String) -> Bool {
    let first = normalizedPlaceName(a)
    let second = normalizedPlaceName(b)
    return first == second
        || (min(first.count, second.count) >= 4
            && (first.hasPrefix(second) || second.hasPrefix(first)))
}

public func normalizedPlaceName(_ name: String) -> String {
    name.lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty && !["nyc", "inc", "llc", "co", "corp"].contains($0) }
        .joined(separator: " ")
}
