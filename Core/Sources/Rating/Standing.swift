import Foundation

/// A place's standing across visits: recency-weighted mean (12-month half-life)
/// with a floor two points under the best score, so one bad night can't erase
/// five good ones (product notes §6 Revisits).
public func standing(for visits: [(score: Int, date: Date)], asOf now: Date = Date()) -> Double {
    guard !visits.isEmpty else { return 0 }
    var weightSum = 0.0
    var weighted = 0.0
    for visit in visits {
        let ageDays = max(0, now.timeIntervalSince(visit.date) / 86_400)
        let weight = pow(0.5, ageDays / 365)
        weightSum += weight
        weighted += weight * Double(visit.score)
    }
    let mean = weighted / weightSum
    let floor = Double(visits.map(\.score).max()!) - 2
    return min(10, max(mean, floor))
}
