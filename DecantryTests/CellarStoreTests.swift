import XCTest
@testable import Decantry

final class CellarStoreTests: XCTestCase {
    func testBottleRoundTrip() async throws {
        let store = try CellarStore(inMemory: true)
        try await DecantMigrator.migrate(store)
        let bottles = BottleRepository(store: store)
        let bottle = Bottle(
            id: UUID(),
            producerID: nil,
            name: "Test Claret",
            kind: .wine,
            vintage: 2018,
            grapeOrBase: "Merlot",
            abvPercent: 13.5,
            purchasedAt: .now,
            purchaseCents: 4200,
            currencyCode: "USD",
            peakStartYear: 2026,
            peakEndYear: 2030,
            cellarTempC: 13,
            note: "Cellar test",
            drunkAt: nil,
            isArchived: false
        )
        try await bottles.upsert(bottle)
        let fetched = try await bottles.fetch(id: bottle.id)
        XCTAssertEqual(fetched?.name, bottle.name)
        XCTAssertEqual(fetched?.purchaseCents, 4200)
    }

    func testBackupRoundTrip() async throws {
        let store = try CellarStore(inMemory: true)
        try await DecantMigrator.migrate(store)
        let profileRepo = DecantProfileRepository(store: store)
        let producerRepo = ProducerRepository(store: store)
        let rackRepo = RackRepository(store: store)
        let cellRepo = CellRepository(store: store)
        let bottleRepo = BottleRepository(store: store)
        let tastingRepo = TastingRepository(store: store)
        let purchaseRepo = PurchaseRepository(store: store)

        let profile = CellarProfile(id: UUID(), displayName: "Test", defaultTempC: 12, currencyCode: "EUR")
        try await profileRepo.upsert(profile)

        let backup = DecantBackupService(
            store: store,
            profileRepo: profileRepo,
            producerRepo: producerRepo,
            rackRepo: rackRepo,
            cellRepo: cellRepo,
            bottleRepo: bottleRepo,
            tastingRepo: tastingRepo,
            purchaseRepo: purchaseRepo
        )

        let data = try await backup.exportJSON()
        let store2 = try CellarStore(inMemory: true)
        try await DecantMigrator.migrate(store2)
        let backup2 = DecantBackupService(
            store: store2,
            profileRepo: DecantProfileRepository(store: store2),
            producerRepo: ProducerRepository(store: store2),
            rackRepo: RackRepository(store: store2),
            cellRepo: CellRepository(store: store2),
            bottleRepo: BottleRepository(store: store2),
            tastingRepo: TastingRepository(store: store2),
            purchaseRepo: PurchaseRepository(store: store2)
        )
        try await backup2.importJSON(data)
        let restored = try await DecantProfileRepository(store: store2).fetch()
        XCTAssertEqual(restored?.displayName, "Test")
        XCTAssertEqual(restored?.currencyCode, "EUR")
    }

    @MainActor
    func testSeedDataPresentAfterBootstrap() async throws {
        let env = AppEnvironment(store: try CellarStore(inMemory: true))
        try await DecantMigrator.migrate(env.store)
        try await CellarSeeder.seedIfNeeded(environment: env)
        let count = try await env.bottles.count()
        XCTAssertGreaterThan(count, 0)
    }
}
