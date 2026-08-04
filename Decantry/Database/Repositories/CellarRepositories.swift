import Foundation

struct DecantProfileRepository: Sendable {
    let store: CellarStore

    func fetch() async throws -> CellarProfile? {
        try await store.queryOne(
            "SELECT id, display_name, default_temp_c, currency_code FROM cellar_profile LIMIT 1;",
            map: RowMappers.profile
        )
    }

    func upsert(_ profile: CellarProfile) async throws {
        try await store.run(
            """
            INSERT INTO cellar_profile (id, display_name, default_temp_c, currency_code)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                display_name = excluded.display_name,
                default_temp_c = excluded.default_temp_c,
                currency_code = excluded.currency_code;
            """
        ) { binder in
            try binder.bind(profile.id, at: 1)
            try binder.bind(profile.displayName, at: 2)
            try binder.bind(profile.defaultTempC, at: 3)
            try binder.bind(profile.currencyCode, at: 4)
        }
    }

    func count() async throws -> Int {
        try await store.scalarInt("SELECT COUNT(*) FROM cellar_profile;")
    }
}

struct ProducerRepository: Sendable {
    let store: CellarStore

    func all() async throws -> [Producer] {
        try await store.query(
            "SELECT id, name, region, country, note FROM producer ORDER BY name;",
            map: RowMappers.producer
        )
    }

    func fetch(id: UUID) async throws -> Producer? {
        try await store.queryOne(
            "SELECT id, name, region, country, note FROM producer WHERE id = ?;",
            bind: { try $0.bind(id, at: 1) },
            map: RowMappers.producer
        )
    }

    func upsert(_ producer: Producer) async throws {
        try await store.run(
            """
            INSERT INTO producer (id, name, region, country, note)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                region = excluded.region,
                country = excluded.country,
                note = excluded.note;
            """
        ) { binder in
            try binder.bind(producer.id, at: 1)
            try binder.bind(producer.name, at: 2)
            try binder.bind(producer.region, at: 3)
            try binder.bind(producer.country, at: 4)
            try binder.bind(producer.note, at: 5)
        }
    }

    func delete(id: UUID) async throws {
        try await store.run("DELETE FROM producer WHERE id = ?;") { try $0.bind(id, at: 1) }
    }
}

struct RackRepository: Sendable {
    let store: CellarStore

    func all() async throws -> [Rack] {
        try await store.query(
            "SELECT id, name, rows, columns, sort_order FROM rack ORDER BY sort_order, name;",
            map: RowMappers.rack
        )
    }

    func fetch(id: UUID) async throws -> Rack? {
        try await store.queryOne(
            "SELECT id, name, rows, columns, sort_order FROM rack WHERE id = ?;",
            bind: { try $0.bind(id, at: 1) },
            map: RowMappers.rack
        )
    }

    func upsert(_ rack: Rack) async throws {
        try await store.run(
            """
            INSERT INTO rack (id, name, rows, columns, sort_order)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                rows = excluded.rows,
                columns = excluded.columns,
                sort_order = excluded.sort_order;
            """
        ) { binder in
            try binder.bind(rack.id, at: 1)
            try binder.bind(rack.name, at: 2)
            try binder.bind(rack.rows, at: 3)
            try binder.bind(rack.columns, at: 4)
            try binder.bind(rack.sortOrder, at: 5)
        }
    }

    func delete(id: UUID) async throws {
        try await store.run("DELETE FROM rack WHERE id = ?;") { try $0.bind(id, at: 1) }
    }
}

struct CellRepository: Sendable {
    let store: CellarStore

    func cells(forRack rackID: UUID) async throws -> [Cell] {
        try await store.query(
            """
            SELECT id, rack_id, row, column, status, bottle_id
            FROM cell WHERE rack_id = ? ORDER BY row, column;
            """,
            bind: { try $0.bind(rackID, at: 1) },
            map: RowMappers.cell
        )
    }

    func upsert(_ cell: Cell) async throws {
        try await store.run(
            """
            INSERT INTO cell (id, rack_id, row, column, status, bottle_id)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                rack_id = excluded.rack_id,
                row = excluded.row,
                column = excluded.column,
                status = excluded.status,
                bottle_id = excluded.bottle_id;
            """
        ) { binder in
            try binder.bind(cell.id, at: 1)
            try binder.bind(cell.rackID, at: 2)
            try binder.bind(cell.row, at: 3)
            try binder.bind(cell.column, at: 4)
            try binder.bind(cell.status.rawValue, at: 5)
            try binder.bindOptional(cell.bottleID, at: 6)
        }
    }

    func createGrid(for rack: Rack) async throws {
        for row in 0..<rack.rows {
            for column in 0..<rack.columns {
                let cell = Cell(
                    id: UUID(),
                    rackID: rack.id,
                    row: row,
                    column: column,
                    status: .empty,
                    bottleID: nil
                )
                try await upsert(cell)
            }
        }
    }
}

struct BottleRepository: Sendable {
    let store: CellarStore

    func all(activeOnly: Bool = false) async throws -> [Bottle] {
        let sql = activeOnly
            ? """
            SELECT id, producer_id, name, kind, vintage, grape_or_base, abv_percent,
                   purchased_at, purchase_cents, currency_code, peak_start_year, peak_end_year,
                   cellar_temp_c, note, drunk_at, is_archived
            FROM bottle WHERE drunk_at IS NULL AND is_archived = 0 ORDER BY name;
            """
            : """
            SELECT id, producer_id, name, kind, vintage, grape_or_base, abv_percent,
                   purchased_at, purchase_cents, currency_code, peak_start_year, peak_end_year,
                   cellar_temp_c, note, drunk_at, is_archived
            FROM bottle ORDER BY name;
            """
        return try await store.query(sql, map: RowMappers.bottle)
    }

    func fetch(id: UUID) async throws -> Bottle? {
        try await store.queryOne(
            """
            SELECT id, producer_id, name, kind, vintage, grape_or_base, abv_percent,
                   purchased_at, purchase_cents, currency_code, peak_start_year, peak_end_year,
                   cellar_temp_c, note, drunk_at, is_archived
            FROM bottle WHERE id = ?;
            """,
            bind: { try $0.bind(id, at: 1) },
            map: RowMappers.bottle
        )
    }

    func upsert(_ bottle: Bottle) async throws {
        try await store.run(
            """
            INSERT INTO bottle (
                id, producer_id, name, kind, vintage, grape_or_base, abv_percent,
                purchased_at, purchase_cents, currency_code, peak_start_year, peak_end_year,
                cellar_temp_c, note, drunk_at, is_archived
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                producer_id = excluded.producer_id,
                name = excluded.name,
                kind = excluded.kind,
                vintage = excluded.vintage,
                grape_or_base = excluded.grape_or_base,
                abv_percent = excluded.abv_percent,
                purchased_at = excluded.purchased_at,
                purchase_cents = excluded.purchase_cents,
                currency_code = excluded.currency_code,
                peak_start_year = excluded.peak_start_year,
                peak_end_year = excluded.peak_end_year,
                cellar_temp_c = excluded.cellar_temp_c,
                note = excluded.note,
                drunk_at = excluded.drunk_at,
                is_archived = excluded.is_archived;
            """
        ) { binder in
            try binder.bind(bottle.id, at: 1)
            try binder.bindOptional(bottle.producerID, at: 2)
            try binder.bind(bottle.name, at: 3)
            try binder.bind(bottle.kind.rawValue, at: 4)
            try binder.bindOptional(bottle.vintage, at: 5)
            try binder.bind(bottle.grapeOrBase, at: 6)
            try binder.bindOptional(bottle.abvPercent, at: 7)
            try binder.bindOptional(bottle.purchasedAt, at: 8)
            try binder.bind(bottle.purchaseCents, at: 9)
            try binder.bind(bottle.currencyCode, at: 10)
            try binder.bindOptional(bottle.peakStartYear, at: 11)
            try binder.bindOptional(bottle.peakEndYear, at: 12)
            try binder.bind(bottle.cellarTempC, at: 13)
            try binder.bind(bottle.note, at: 14)
            try binder.bindOptional(bottle.drunkAt, at: 15)
            try binder.bind(bottle.isArchived, at: 16)
        }
    }

    func delete(id: UUID) async throws {
        try await store.run("DELETE FROM bottle WHERE id = ?;") { try $0.bind(id, at: 1) }
    }

    func count() async throws -> Int {
        try await store.scalarInt("SELECT COUNT(*) FROM bottle;")
    }
}

struct TastingRepository: Sendable {
    let store: CellarStore

    func all() async throws -> [Tasting] {
        try await store.query(
            """
            SELECT id, bottle_id, tasted_at, score, nose, palate, finish, note
            FROM tasting ORDER BY tasted_at DESC;
            """,
            map: RowMappers.tasting
        )
    }

    func forBottle(_ bottleID: UUID) async throws -> [Tasting] {
        try await store.query(
            """
            SELECT id, bottle_id, tasted_at, score, nose, palate, finish, note
            FROM tasting WHERE bottle_id = ? ORDER BY tasted_at DESC;
            """,
            bind: { try $0.bind(bottleID, at: 1) },
            map: RowMappers.tasting
        )
    }

    func count(forBottle bottleID: UUID) async throws -> Int {
        try await store.scalarInt(
            "SELECT COUNT(*) FROM tasting WHERE bottle_id = ?;",
            { try $0.bind(bottleID, at: 1) }
        )
    }

    func upsert(_ tasting: Tasting) async throws {
        try await store.run(
            """
            INSERT INTO tasting (id, bottle_id, tasted_at, score, nose, palate, finish, note)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                bottle_id = excluded.bottle_id,
                tasted_at = excluded.tasted_at,
                score = excluded.score,
                nose = excluded.nose,
                palate = excluded.palate,
                finish = excluded.finish,
                note = excluded.note;
            """
        ) { binder in
            try binder.bind(tasting.id, at: 1)
            try binder.bind(tasting.bottleID, at: 2)
            try binder.bind(tasting.tastedAt, at: 3)
            try binder.bind(tasting.score, at: 4)
            try binder.bind(tasting.nose, at: 5)
            try binder.bind(tasting.palate, at: 6)
            try binder.bind(tasting.finish, at: 7)
            try binder.bind(tasting.note, at: 8)
        }
    }

    func delete(id: UUID) async throws {
        try await store.run("DELETE FROM tasting WHERE id = ?;") { try $0.bind(id, at: 1) }
    }
}

struct PurchaseRepository: Sendable {
    let store: CellarStore

    func all() async throws -> [Purchase] {
        try await store.query(
            """
            SELECT id, bottle_id, purchased_at, store_name, cents, quantity
            FROM purchase ORDER BY purchased_at DESC;
            """,
            map: RowMappers.purchase
        )
    }

    func forBottle(_ bottleID: UUID) async throws -> [Purchase] {
        try await store.query(
            """
            SELECT id, bottle_id, purchased_at, store_name, cents, quantity
            FROM purchase WHERE bottle_id = ? ORDER BY purchased_at DESC;
            """,
            bind: { try $0.bind(bottleID, at: 1) },
            map: RowMappers.purchase
        )
    }

    func upsert(_ purchase: Purchase) async throws {
        try await store.run(
            """
            INSERT INTO purchase (id, bottle_id, purchased_at, store_name, cents, quantity)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                bottle_id = excluded.bottle_id,
                purchased_at = excluded.purchased_at,
                store_name = excluded.store_name,
                cents = excluded.cents,
                quantity = excluded.quantity;
            """
        ) { binder in
            try binder.bind(purchase.id, at: 1)
            try binder.bind(purchase.bottleID, at: 2)
            try binder.bind(purchase.purchasedAt, at: 3)
            try binder.bind(purchase.storeName, at: 4)
            try binder.bind(purchase.cents, at: 5)
            try binder.bind(purchase.quantity, at: 6)
        }
    }
}
