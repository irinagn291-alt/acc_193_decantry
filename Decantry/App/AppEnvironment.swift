import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let store: CellarStore
    let profile: DecantProfileRepository
    let producers: ProducerRepository
    let racks: RackRepository
    let cells: CellRepository
    let bottles: BottleRepository
    let tastings: TastingRepository
    let purchases: PurchaseRepository
    let backup: DecantBackupService

    @Published private(set) var isReady = false
    @Published private(set) var bootstrapError: String?
    @Published var cellarProfile: CellarProfile?

    init(store: CellarStore, bootstrapError: String? = nil) {
        self.store = store
        self.bootstrapError = bootstrapError
        self.profile = DecantProfileRepository(store: store)
        self.producers = ProducerRepository(store: store)
        self.racks = RackRepository(store: store)
        self.cells = CellRepository(store: store)
        self.bottles = BottleRepository(store: store)
        self.tastings = TastingRepository(store: store)
        self.purchases = PurchaseRepository(store: store)
        self.backup = DecantBackupService(
            store: store,
            profileRepo: profile,
            producerRepo: producers,
            rackRepo: racks,
            cellRepo: cells,
            bottleRepo: bottles,
            tastingRepo: tastings,
            purchaseRepo: purchases
        )
    }

    static func live() -> AppEnvironment {
        do {
            return AppEnvironment(store: try CellarStore(path: try CellarStore.applicationSupportPath()))
        } catch let openError {
            do {
                return AppEnvironment(
                    store: try CellarStore(inMemory: true),
                    bootstrapError: openError.localizedDescription
                )
            } catch {
                preconditionFailure("Unable to open cellar store: \(openError)")
            }
        }
    }

    func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: DecantDefaults.onboardingCompleted)
    }

    func bootstrap() async {
        do {
            try DecantPaths.ensureDirectories()
            try await DecantMigrator.migrate(store)
            try await CellarSeeder.seedIfNeeded(environment: self)
            cellarProfile = try await profile.fetch()
            if let code = cellarProfile?.currencyCode {
                DecantMoney.currencyCode = code
            }
            isReady = true
        } catch {
            bootstrapError = error.localizedDescription
        }
    }

    func reloadProfile() async {
        cellarProfile = try? await profile.fetch()
        if let code = cellarProfile?.currencyCode {
            DecantMoney.currencyCode = code
        }
    }

    func storeFileSize() -> Int64 {
        store.fileSize()
    }
}
