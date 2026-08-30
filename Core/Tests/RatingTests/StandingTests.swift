import Foundation
import Testing
@testable import Rating

private func day(_ offset: Int) -> Date { Date(timeIntervalSinceReferenceDate: Double(offset) * 86_400) }

@Test func singleVisitStandingIsItsScore() {
    #expect(standing(for: [(score: 8, date: day(0))], asOf: day(0)) == 8)
}

@Test func recentVisitsWeighMoreThanOldOnes() {
    let value = standing(for: [(score: 9, date: day(360)), (score: 5, date: day(0))], asOf: day(365))
    #expect(value > 7)  // the recent 9 dominates the year-old 5
}

@Test func oneBadNightCannotEraseGoodHistory() {
    let visits = (0..<5).map { (score: 9, date: day($0 * 30)) } + [(score: 2, date: day(160))]
    let value = standing(for: visits, asOf: day(160))
    #expect(value >= 7)  // floored at best score minus two
}
