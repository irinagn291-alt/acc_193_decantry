import Foundation

enum MaturityStage: String, Codable, CaseIterable, Sendable {
    case young, approaching, ready, holding, pastPeak
    var title: String {
        switch self {
        case .young: return "Young"
        case .approaching: return "Approaching"
        case .ready: return "Ready"
        case .holding: return "Holding"
        case .pastPeak: return "Past peak"
        }
    }
}

enum BottleKind: String, Codable, CaseIterable, Sendable {
    case wine, spirit, fortified, other
}

enum CellStatus: String, Codable, CaseIterable, Sendable {
    case empty, occupied, reserved
}

struct Producer: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var region: String
    var country: String
    var note: String
}

struct Rack: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var rows: Int
    var columns: Int
    var sortOrder: Int
}

struct Cell: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var rackID: UUID
    var row: Int
    var column: Int
    var status: CellStatus
    var bottleID: UUID?
}

struct Bottle: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var producerID: UUID?
    var name: String
    var kind: BottleKind
    var vintage: Int?
    var grapeOrBase: String
    var abvPercent: Double?
    var purchasedAt: Date?
    var purchaseCents: Int
    var currencyCode: String
    var peakStartYear: Int?
    var peakEndYear: Int?
    var cellarTempC: Double
    var note: String
    var drunkAt: Date?
    var isArchived: Bool
}

struct Tasting: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var bottleID: UUID
    var tastedAt: Date
    var score: Int
    var nose: String
    var palate: String
    var finish: String
    var note: String
}

struct Purchase: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var bottleID: UUID
    var purchasedAt: Date
    var storeName: String
    var cents: Int
    var quantity: Int
}

struct CellarProfile: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var displayName: String
    var defaultTempC: Double
    var currencyCode: String
}

struct BottleWindow: Hashable, Sendable {
    let bottleID: UUID
    let stage: MaturityStage
    let remainingDays: Int?
    let peakLabel: String
}
