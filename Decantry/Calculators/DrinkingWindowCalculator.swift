import Foundation

enum DrinkingWindowCalculator {
    static func stage(
        vintage: Int?,
        peakStartYear: Int?,
        peakEndYear: Int?,
        cellarTempC: Double,
        asOf: Date = Date()
    ) -> MaturityStage {
        let year = Calendar.current.component(.year, from: asOf)
        let start = peakStartYear ?? ((vintage ?? year) + 5)
        let end = peakEndYear ?? (start + 4)
        let tempFactor = (cellarTempC - 13.0) * 0.5
        let adjustedStart = Double(start) - tempFactor
        let adjustedEnd = Double(end) - tempFactor
        let y = Double(year)
        if y < adjustedStart - 3 { return .young }
        if y < adjustedStart { return .approaching }
        if y <= adjustedEnd { return .ready }
        if y <= adjustedEnd + 2 { return .holding }
        return .pastPeak
    }

    static func remainingDays(
        peakEndYear: Int?,
        vintage: Int?,
        cellarTempC: Double,
        asOf: Date = Date()
    ) -> Int? {
        let year = Calendar.current.component(.year, from: asOf)
        let end = peakEndYear ?? ((vintage ?? year) + 9)
        let tempFactor = (cellarTempC - 13.0) * 0.5
        let adjustedEnd = Double(end) - tempFactor
        let days = Int((adjustedEnd - Double(year)) * 365.0)
        return days
    }

    static func window(for bottle: Bottle, asOf: Date = Date()) -> BottleWindow {
        let st = stage(
            vintage: bottle.vintage,
            peakStartYear: bottle.peakStartYear,
            peakEndYear: bottle.peakEndYear,
            cellarTempC: bottle.cellarTempC,
            asOf: asOf
        )
        let rem = remainingDays(
            peakEndYear: bottle.peakEndYear,
            vintage: bottle.vintage,
            cellarTempC: bottle.cellarTempC,
            asOf: asOf
        )
        let peak = "\(bottle.peakStartYear ?? 0)–\(bottle.peakEndYear ?? 0)"
        return BottleWindow(bottleID: bottle.id, stage: st, remainingDays: rem, peakLabel: peak)
    }

    static func closingThisWeek(bottles: [Bottle], asOf: Date = Date()) -> [Bottle] {
        bottles.filter { bottle in
            guard bottle.drunkAt == nil, !bottle.isArchived else { return false }
            let w = window(for: bottle, asOf: asOf)
            guard w.stage == .ready || w.stage == .holding else { return false }
            if let rem = w.remainingDays { return rem <= 7 }
            return w.stage == .holding
        }
    }

    static func averageCostPerTasting(purchaseCents: Int, tastingCount: Int) -> Int {
        purchaseCents / max(1, tastingCount)
    }
}
