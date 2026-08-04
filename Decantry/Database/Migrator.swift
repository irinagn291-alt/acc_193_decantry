import Foundation

enum DecantMigrator {
    static let currentVersion = 1

    static func migrate(_ store: CellarStore) async throws {
        let version = try await store.userVersion()
        if version > currentVersion {
            throw StoreFault.futureVersion(version)
        }
        if version < 1 {
            try await store.applySchema(DecantSchemaV1.sql, version: 1)
        }
    }
}

enum DecantSchemaV1 {
    static let sql = """
    CREATE TABLE IF NOT EXISTS cellar_profile (
        id TEXT PRIMARY KEY NOT NULL,
        display_name TEXT NOT NULL,
        default_temp_c REAL NOT NULL,
        currency_code TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS producer (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        region TEXT NOT NULL,
        country TEXT NOT NULL,
        note TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS rack (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        rows INTEGER NOT NULL,
        columns INTEGER NOT NULL,
        sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS bottle (
        id TEXT PRIMARY KEY NOT NULL,
        producer_id TEXT REFERENCES producer(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        vintage INTEGER,
        grape_or_base TEXT NOT NULL,
        abv_percent REAL,
        purchased_at INTEGER,
        purchase_cents INTEGER NOT NULL,
        currency_code TEXT NOT NULL,
        peak_start_year INTEGER,
        peak_end_year INTEGER,
        cellar_temp_c REAL NOT NULL,
        note TEXT NOT NULL,
        drunk_at INTEGER,
        is_archived INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS cell (
        id TEXT PRIMARY KEY NOT NULL,
        rack_id TEXT NOT NULL REFERENCES rack(id) ON DELETE CASCADE,
        row INTEGER NOT NULL,
        column INTEGER NOT NULL,
        status TEXT NOT NULL,
        bottle_id TEXT REFERENCES bottle(id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS tasting (
        id TEXT PRIMARY KEY NOT NULL,
        bottle_id TEXT NOT NULL REFERENCES bottle(id) ON DELETE CASCADE,
        tasted_at INTEGER NOT NULL,
        score INTEGER NOT NULL,
        nose TEXT NOT NULL,
        palate TEXT NOT NULL,
        finish TEXT NOT NULL,
        note TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS purchase (
        id TEXT PRIMARY KEY NOT NULL,
        bottle_id TEXT NOT NULL REFERENCES bottle(id) ON DELETE CASCADE,
        purchased_at INTEGER NOT NULL,
        store_name TEXT NOT NULL,
        cents INTEGER NOT NULL,
        quantity INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_cell_rack ON cell(rack_id);
    CREATE INDEX IF NOT EXISTS idx_bottle_producer ON bottle(producer_id);
    CREATE INDEX IF NOT EXISTS idx_tasting_bottle ON tasting(bottle_id);
    CREATE INDEX IF NOT EXISTS idx_purchase_bottle ON purchase(bottle_id);
    """
}
