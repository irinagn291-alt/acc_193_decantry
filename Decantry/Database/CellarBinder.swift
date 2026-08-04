import Foundation
import SQLite3

final class CellarBinder: @unchecked Sendable {
    private var pointer: OpaquePointer?
    private let database: OpaquePointer

    init(database: OpaquePointer, sql: String) throws {
        self.database = database
        var stmt: OpaquePointer?
        let code = sqlite3_prepare_v2(database, sql, -1, &stmt, nil)
        guard code == SQLITE_OK, let stmt else {
            throw StoreFault.prepareFailed(StoreFault.message(from: database))
        }
        pointer = stmt
    }

    func finalize() {
        if let pointer {
            sqlite3_finalize(pointer)
            self.pointer = nil
        }
    }

    deinit {
        finalize()
    }

    private var stmt: OpaquePointer {
        get throws {
            guard let pointer else { throw StoreFault.notOpen }
            return pointer
        }
    }

    @discardableResult
    func step() throws -> Bool {
        var attempt = 0
        while true {
            let code = sqlite3_step(try stmt)
            switch code {
            case SQLITE_ROW: return true
            case SQLITE_DONE: return false
            case SQLITE_BUSY, SQLITE_LOCKED:
                guard attempt < CellarStore.busyRetryLimit else {
                    throw StoreFault.stepFailed(StoreFault.message(from: database))
                }
                usleep(CellarStore.busyRetryBaseDelay << attempt)
                attempt += 1
                _ = sqlite3_reset(try stmt)
            default:
                let message = StoreFault.message(from: database)
                if code == SQLITE_CONSTRAINT {
                    throw StoreFault.constraint(message)
                }
                throw StoreFault.stepFailed(message)
            }
        }
    }

    func bindNull(_ index: Int32) throws {
        guard sqlite3_bind_null(try stmt, index) == SQLITE_OK else {
            throw StoreFault.bindFailed(StoreFault.message(from: database))
        }
    }

    func bind(_ value: Int, at index: Int32) throws {
        try bind(Int64(value), at: index)
    }

    func bind(_ value: Int64, at index: Int32) throws {
        guard sqlite3_bind_int64(try stmt, index, value) == SQLITE_OK else {
            throw StoreFault.bindFailed(StoreFault.message(from: database))
        }
    }

    func bind(_ value: Double, at index: Int32) throws {
        guard sqlite3_bind_double(try stmt, index, value) == SQLITE_OK else {
            throw StoreFault.bindFailed(StoreFault.message(from: database))
        }
    }

    func bind(_ value: String, at index: Int32) throws {
        let code = sqlite3_bind_text(try stmt, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard code == SQLITE_OK else {
            throw StoreFault.bindFailed(StoreFault.message(from: database))
        }
    }

    func bind(_ value: Bool, at index: Int32) throws {
        try bind(value ? 1 : 0, at: index)
    }

    func bind(_ value: UUID, at index: Int32) throws {
        try bind(value.uuidString.lowercased(), at: index)
    }

    func bind(_ value: Date, at index: Int32) throws {
        try bind(try Self.epochSeconds(value), at: index)
    }

    static func epochSeconds(_ date: Date) throws -> Int64 {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite,
              seconds >= Double(Int64.min),
              seconds <= Double(Int64.max) else {
            throw StoreFault.bindFailed("Date out of representable range")
        }
        return Int64(seconds)
    }

    func bindOptional(_ value: Double?, at index: Int32) throws {
        if let value { try bind(value, at: index) } else { try bindNull(index) }
    }

    func bindOptional(_ value: Int?, at index: Int32) throws {
        if let value { try bind(value, at: index) } else { try bindNull(index) }
    }

    func bindOptional(_ value: Date?, at index: Int32) throws {
        if let value { try bind(value, at: index) } else { try bindNull(index) }
    }

    func bindOptional(_ value: String?, at index: Int32) throws {
        if let value { try bind(value, at: index) } else { try bindNull(index) }
    }

    func bindOptional(_ value: UUID?, at index: Int32) throws {
        if let value { try bind(value, at: index) } else { try bindNull(index) }
    }

    func int(at index: Int32) -> Int {
        Int(sqlite3_column_int64(pointer, index))
    }

    func columnName(at index: Int32) -> String {
        guard let name = sqlite3_column_name(pointer, index) else { return "" }
        return String(cString: name)
    }

    func columnCount() -> Int32 {
        sqlite3_column_count(pointer)
    }

    func readRow() -> Row {
        var map: [String: SQLValue] = [:]
        let count = columnCount()
        for i in 0..<count {
            let name = columnName(at: i)
            let type = sqlite3_column_type(pointer, i)
            let value: SQLValue
            switch type {
            case SQLITE_NULL: value = .null
            case SQLITE_INTEGER: value = .integer(sqlite3_column_int64(pointer, i))
            case SQLITE_FLOAT: value = .real(sqlite3_column_double(pointer, i))
            case SQLITE_TEXT:
                if let cString = sqlite3_column_text(pointer, i) {
                    value = .text(String(cString: cString))
                } else {
                    value = .null
                }
            case SQLITE_BLOB:
                if let bytes = sqlite3_column_blob(pointer, i) {
                    let size = Int(sqlite3_column_bytes(pointer, i))
                    value = .blob(Data(bytes: bytes, count: size))
                } else {
                    value = .blob(Data())
                }
            default: value = .null
            }
            map[name] = value
        }
        return Row(map)
    }
}
