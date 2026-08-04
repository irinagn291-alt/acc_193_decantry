import XCTest
@testable import Decantry

final class DrinkingWindowCalculatorTests: XCTestCase {
    func testYoungStageWhenFarBeforePeak() {
        let stage = DrinkingWindowCalculator.stage(
            vintage: 2020,
            peakStartYear: 2030,
            peakEndYear: 2035,
            cellarTempC: 13,
            asOf: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(stage, .young)
    }

    func testReadyInsidePeakWindow() {
        let stage = DrinkingWindowCalculator.stage(
            vintage: 2015,
            peakStartYear: 2024,
            peakEndYear: 2030,
            cellarTempC: 13,
            asOf: date(year: 2026, month: 6, day: 1)
        )
        XCTAssertEqual(stage, .ready)
    }

    func testTempAbove13ShortensWindow() {
        let cool = DrinkingWindowCalculator.stage(
            vintage: 2010,
            peakStartYear: 2020,
            peakEndYear: 2024,
            cellarTempC: 13,
            asOf: date(year: 2025, month: 1, day: 1)
        )
        let warm = DrinkingWindowCalculator.stage(
            vintage: 2010,
            peakStartYear: 2020,
            peakEndYear: 2024,
            cellarTempC: 17,
            asOf: date(year: 2025, month: 1, day: 1)
        )
        XCTAssertEqual(cool, .holding)
        XCTAssertEqual(warm, .pastPeak)
    }

    func testClosingThisWeekIncludesReadyWithLowRemainingDays() {
        let bottle = Bottle(
            id: UUID(),
            producerID: nil,
            name: "Test",
            kind: .wine,
            vintage: 2012,
            grapeOrBase: "",
            abvPercent: nil,
            purchasedAt: nil,
            purchaseCents: 1000,
            currencyCode: "USD",
            peakStartYear: 2020,
            peakEndYear: 2026,
            cellarTempC: 13,
            note: "",
            drunkAt: nil,
            isArchived: false
        )
        let closing = DrinkingWindowCalculator.closingThisWeek(bottles: [bottle], asOf: date(year: 2026, month: 1, day: 1))
        XCTAssertEqual(closing.count, 1)
    }

    func testAverageCostPerTasting() {
        XCTAssertEqual(DrinkingWindowCalculator.averageCostPerTasting(purchaseCents: 5000, tastingCount: 0), 5000)
        XCTAssertEqual(DrinkingWindowCalculator.averageCostPerTasting(purchaseCents: 5000, tastingCount: 2), 2500)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
