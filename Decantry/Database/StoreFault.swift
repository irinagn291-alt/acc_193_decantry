import Foundation
import SQLite3

enum StoreFault: Error, LocalizedError, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case futureVersion(Int)
    case unexpectedNull
    case notOpen
    case constraint(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let m): "Failed to open cellar store: \(m)"
        case .prepareFailed(let m): "Failed to prepare query: \(m)"
        case .stepFailed(let m): "Query failed: \(m)"
        case .bindFailed(let m): "Failed to bind value: \(m)"
        case .futureVersion(let v): "Database version \(v) is newer than this app supports."
        case .unexpectedNull: "Unexpected NULL column."
        case .notOpen: "Cellar store is not open."
        case .constraint(let m): "Constraint failed: \(m)"
        }
    }

    static func message(from db: OpaquePointer?) -> String {
        if let db, let cString = sqlite3_errmsg(db) {
            return String(cString: cString)
        }
        return "unknown error"
    }
}
