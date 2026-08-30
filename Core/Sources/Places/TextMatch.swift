import Foundation

/// Which candidate's name appears in text recognized from the photos —
/// receipts, menus, storefront signs. Returns the index only when exactly one
/// candidate matches: a unique name-in-image is near-certain identification,
/// zero or several matches decide nothing.
public func uniqueTextMatch(candidateNames: [String], recognizedStrings: [String]) -> Int? {
    let corpus = " " + recognizedStrings.map(normalizedPlaceName).joined(separator: " ") + " "
    var matches: [Int] = []
    for (index, name) in candidateNames.enumerated() {
        let normalized = normalizedPlaceName(name)
        // Single generic words ("cafe", "bar") match everything; demand either
        // a multi-word name or a distinctive single token.
        guard normalized.count >= 4, normalized.contains(" ") || normalized.count >= 5 else { continue }
        if corpus.contains(" " + normalized + " ") || corpus.contains(normalized) {
            matches.append(index)
        }
    }
    return matches.count == 1 ? matches.first : nil
}
