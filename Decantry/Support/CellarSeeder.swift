import Foundation

enum CellarSeeder {
    static let seedVersion = 2

    /// Demo cellar for Simulator only — never runs on a physical device.
    static func seedIfNeeded(environment: AppEnvironment) async throws {
        #if targetEnvironment(simulator)
        let stored = UserDefaults.standard.integer(forKey: DecantDefaults.seedVersion)
        let bottleCount = try await environment.bottles.all(activeOnly: false).count
        guard stored < seedVersion || bottleCount == 0 else { return }
        try await installDemoCellar(environment: environment)
        UserDefaults.standard.set(seedVersion, forKey: DecantDefaults.seedVersion)
        UserDefaults.standard.set(true, forKey: DecantDefaults.onboardingCompleted)
        #endif
    }

    #if targetEnvironment(simulator)
    private static func installDemoCellar(environment: AppEnvironment) async throws {
        let profile = CellarProfile(
            id: UUID(),
            displayName: "Home Cellar",
            defaultTempC: 13.0,
            currencyCode: "USD"
        )
        try await environment.profile.upsert(profile)

        let producers = [
            Producer(id: UUID(), name: "Château Demo", region: "Bordeaux", country: "France", note: "Left bank classic."),
            Producer(id: UUID(), name: "Ridge Estate", region: "Santa Cruz", country: "USA", note: "Mountain fruit."),
            Producer(id: UUID(), name: "Barolo Vecchio", region: "Piedmont", country: "Italy", note: "Nebbiolo house.")
        ]
        for producer in producers {
            try await environment.producers.upsert(producer)
        }

        let rack = Rack(id: UUID(), name: "Main Wall", rows: 3, columns: 5, sortOrder: 0)
        try await environment.racks.upsert(rack)
        try await environment.cells.createGrid(for: rack)
        var cells = try await environment.cells.cells(forRack: rack.id)
        cells.sort { ($0.row, $0.column) < ($1.row, $1.column) }

        let year = Calendar.current.component(.year, from: .now)
        let demos: [(String, UUID, Int, Int, Int, Int, String)] = [
            ("Claret Reserve", producers[0].id, year - 8, year - 1, year + 4, 4500, "Cabernet blend"),
            ("Monte Bello", producers[1].id, year - 6, year, year + 6, 8900, "Cabernet Sauvignon"),
            ("Barolo Riserva", producers[2].id, year - 10, year - 2, year + 2, 7200, "Nebbiolo"),
            ("House Blanc", producers[0].id, year - 3, year - 1, year + 1, 2800, "Sauvignon Blanc"),
            ("Late Harvest", producers[1].id, year - 12, year - 4, year - 1, 5100, "Riesling"),
            ("Village Pinot", producers[2].id, year - 5, year, year + 3, 3600, "Pinot Noir"),
            ("Port Reserve", producers[0].id, year - 15, year - 5, year + 10, 6400, "Touriga")
        ]

        for (index, demo) in demos.enumerated() {
            let bottle = Bottle(
                id: UUID(),
                producerID: demo.1,
                name: demo.0,
                kind: index == 6 ? .fortified : .wine,
                vintage: demo.2,
                grapeOrBase: demo.6,
                abvPercent: 13.5,
                purchasedAt: Calendar.current.date(byAdding: .month, value: -(index + 2) * 3, to: .now),
                purchaseCents: demo.5,
                currencyCode: "USD",
                peakStartYear: demo.3,
                peakEndYear: demo.4,
                cellarTempC: 13,
                note: "Simulator demo bottle.",
                drunkAt: nil,
                isArchived: false
            )
            try await environment.bottles.upsert(bottle)
            if index < cells.count {
                let cell = cells[index]
                try await environment.cells.upsert(
                    Cell(
                        id: cell.id,
                        rackID: cell.rackID,
                        row: cell.row,
                        column: cell.column,
                        status: .occupied,
                        bottleID: bottle.id
                    )
                )
            }
            try await environment.purchases.upsert(
                Purchase(
                    id: UUID(),
                    bottleID: bottle.id,
                    purchasedAt: bottle.purchasedAt ?? .now,
                    storeName: index % 2 == 0 ? "Local Wine Shop" : "Importer Case",
                    cents: bottle.purchaseCents,
                    quantity: 1
                )
            )
            if index < 3 {
                try await environment.tastings.upsert(
                    Tasting(
                        id: UUID(),
                        bottleID: bottle.id,
                        tastedAt: Calendar.current.date(byAdding: .day, value: -(index + 1) * 12, to: .now) ?? .now,
                        score: 88 + index,
                        nose: "Dark fruit",
                        palate: "Structured",
                        finish: "Long",
                        note: "Demo tasting."
                    )
                )
            }
        }
    }
    #endif
}
