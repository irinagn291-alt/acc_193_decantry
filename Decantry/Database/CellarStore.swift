import Foundation
import SQLite3

actor CellarStore {
    nonisolated(unsafe) private var handle: OpaquePointer?
    nonisolated(unsafe) private var openedPath: String?
    private var transactionDepth = 0
    private var savepointCounter = 0

    static let busyRetryLimit = 5
    static let busyRetryBaseDelay: useconds_t = 10_000

    static func applicationSupportPath(fileName: String = "decantry.sqlite") throws -> String {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = root.appendingPathComponent("Decantry", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName).path
    }

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let code = sqlite3_open_v2(path, &db, flags, nil)
        guard code == SQLITE_OK, let db else {
            throw StoreFault.openFailed(StoreFault.message(from: db))
        }
        handle = db
        openedPath = path
        try Self.applyPragmas(db)
    }

    init(inMemory: Bool) throws {
        precondition(inMemory)
        try self.init(path: ":memory:")
    }

    deinit {
        if let handle {
            sqlite3_close_v2(handle)
        }
    }

    private static func applyPragmas(_ db: OpaquePointer) throws {
        try exec(db, "PRAGMA journal_mode = WAL;")
        try exec(db, "PRAGMA foreign_keys = ON;")
        try exec(db, "PRAGMA busy_timeout = 5000;")
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var attempt = 0
        while true {
            var errorMessage: UnsafeMutablePointer<CChar>?
            let code = sqlite3_exec(db, sql, nil, nil, &errorMessage)
            if code == SQLITE_OK {
                sqlite3_free(errorMessage)
                return
            }
            let message = errorMessage.map { String(cString: $0) } ?? StoreFault.message(from: db)
            sqlite3_free(errorMessage)
            guard (code == SQLITE_BUSY || code == SQLITE_LOCKED), attempt < busyRetryLimit else {
                if code == SQLITE_CONSTRAINT { throw StoreFault.constraint(message) }
                throw StoreFault.stepFailed(message)
            }
            usleep(busyRetryBaseDelay << attempt)
            attempt += 1
        }
    }

    private func db() throws -> OpaquePointer {
        guard let handle else { throw StoreFault.notOpen }
        return handle
    }

    func execute(_ sql: String) throws {
        try Self.exec(try db(), sql)
    }

    private func prepare(_ sql: String) throws -> CellarBinder {
        try CellarBinder(database: try db(), sql: sql)
    }

    private func withBinder<T>(_ sql: String, _ body: (CellarBinder) throws -> T) throws -> T {
        let binder = try prepare(sql)
        defer { binder.finalize() }
        return try body(binder)
    }

    func run(_ sql: String, _ bind: (CellarBinder) throws -> Void = { _ in }) throws {
        try withBinder(sql) { binder in
            try bind(binder)
            _ = try binder.step()
        }
    }

    func query<T>(
        _ sql: String,
        bind: (CellarBinder) throws -> Void = { _ in },
        map: (Row) throws -> T
    ) throws -> [T] {
        try withBinder(sql) { binder in
            try bind(binder)
            var rows: [T] = []
            while try binder.step() {
                rows.append(try map(binder.readRow()))
            }
            return rows
        }
    }

    func queryOne<T>(
        _ sql: String,
        bind: (CellarBinder) throws -> Void = { _ in },
        map: (Row) throws -> T
    ) throws -> T? {
        try withBinder(sql) { binder in
            try bind(binder)
            guard try binder.step() else { return nil }
            return try map(binder.readRow())
        }
    }

    func scalarInt(_ sql: String, _ bind: (CellarBinder) throws -> Void = { _ in }) throws -> Int {
        try withBinder(sql) { binder in
            try bind(binder)
            guard try binder.step() else { return 0 }
            return binder.int(at: 0)
        }
    }

    func userVersion() throws -> Int {
        try scalarInt("PRAGMA user_version;")
    }

    func setUserVersion(_ version: Int) throws {
        guard version >= 0, version <= Int(Int32.max) else {
            throw StoreFault.stepFailed("Invalid schema version \(version)")
        }
        try execute("PRAGMA user_version = \(version);")
    }

    func applySchema(_ sql: String, version: Int) throws {
        try withTransaction {
            try execute(sql)
            try setUserVersion(version)
        }
    }

    func withTransaction<T>(_ body: () throws -> T) throws -> T {
        if transactionDepth == 0 {
            try execute("BEGIN IMMEDIATE;")
            transactionDepth = 1
            do {
                let result = try body()
                try execute("COMMIT;")
                transactionDepth = 0
                return result
            } catch {
                transactionDepth = 0
                try? execute("ROLLBACK;")
                throw error
            }
        }

        savepointCounter += 1
        let name = "sp_\(savepointCounter)"
        try execute("SAVEPOINT \(name);")
        transactionDepth += 1
        do {
            let result = try body()
            try execute("RELEASE SAVEPOINT \(name);")
            transactionDepth -= 1
            return result
        } catch {
            transactionDepth -= 1
            try? execute("ROLLBACK TO SAVEPOINT \(name);")
            try? execute("RELEASE SAVEPOINT \(name);")
            throw error
        }
    }

    nonisolated func fileSize() -> Int64 {
        guard let path = openedPath, path != ":memory:" else { return 0 }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    func clearAllData() throws {
        try withTransaction {
            try execute("DELETE FROM purchase;")
            try execute("DELETE FROM tasting;")
            try execute("DELETE FROM cell;")
            try execute("DELETE FROM bottle;")
            try execute("DELETE FROM rack;")
            try execute("DELETE FROM producer;")
            try execute("DELETE FROM cellar_profile;")
        }
    }
}
