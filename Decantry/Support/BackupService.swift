import Foundation

struct CellarBackupManifest: Codable, Sendable {
    var schemaVersion: Int
    var exportedAt: Date
    var appVersion: String
}

struct CellarBackupPayload: Codable, Sendable {
    var manifest: CellarBackupManifest
    var profile: CellarProfile?
    var producers: [Producer] = []
    var racks: [Rack] = []
    var cells: [Cell] = []
    var bottles: [Bottle] = []
    var tastings: [Tasting] = []
    var purchases: [Purchase] = []

    init(manifest: CellarBackupManifest) {
        self.manifest = manifest
    }
}

enum DecantBackupError: Error, LocalizedError, Sendable {
    case unsupportedVersion(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v): "Backup schema version \(v) is not supported."
        case .invalidPayload: "The backup file could not be read."
        }
    }
}

struct DecantBackupService: Sendable {
    let store: CellarStore
    let profileRepo: DecantProfileRepository
    let producerRepo: ProducerRepository
    let rackRepo: RackRepository
    let cellRepo: CellRepository
    let bottleRepo: BottleRepository
    let tastingRepo: TastingRepository
    let purchaseRepo: PurchaseRepository

    func exportPayload() async throws -> CellarBackupPayload {
        let manifest = CellarBackupManifest(
            schemaVersion: DecantMigrator.currentVersion,
            exportedAt: .now,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        var payload = CellarBackupPayload(manifest: manifest)
        payload.profile = try await profileRepo.fetch()
        payload.producers = try await producerRepo.all()
        payload.racks = try await rackRepo.all()
        for rack in payload.racks {
            payload.cells.append(contentsOf: try await cellRepo.cells(forRack: rack.id))
        }
        payload.bottles = try await bottleRepo.all()
        payload.tastings = try await tastingRepo.all()
        payload.purchases = try await purchaseRepo.all()
        return payload
    }

    func exportJSON() async throws -> Data {
        let payload = try await exportPayload()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    func writeBackupFile() async throws -> URL {
        try DecantPaths.ensureDirectories()
        let data = try await exportJSON()
        let name = "decantry-backup-\(Int(Date().timeIntervalSince1970)).json"
        let url = DecantPaths.backupsDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    func importJSON(_ data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(CellarBackupPayload.self, from: data)
        guard payload.manifest.schemaVersion <= DecantMigrator.currentVersion else {
            throw DecantBackupError.unsupportedVersion(payload.manifest.schemaVersion)
        }
        try await store.clearAllData()
        if let profile = payload.profile {
            try await profileRepo.upsert(profile)
        }
        for producer in payload.producers {
            try await producerRepo.upsert(producer)
        }
        for rack in payload.racks {
            try await rackRepo.upsert(rack)
        }
        for cell in payload.cells {
            try await cellRepo.upsert(cell)
        }
        for bottle in payload.bottles {
            try await bottleRepo.upsert(bottle)
        }
        for tasting in payload.tastings {
            try await tastingRepo.upsert(tasting)
        }
        for purchase in payload.purchases {
            try await purchaseRepo.upsert(purchase)
        }
    }
}
