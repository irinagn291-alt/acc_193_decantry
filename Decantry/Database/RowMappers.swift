import Foundation

enum RowMappers {
    static func profile(_ row: Row) throws -> CellarProfile {
        CellarProfile(
            id: try row.uuid("id"),
            displayName: try row.string("display_name"),
            defaultTempC: try row.double("default_temp_c"),
            currencyCode: try row.string("currency_code")
        )
    }

    static func producer(_ row: Row) throws -> Producer {
        Producer(
            id: try row.uuid("id"),
            name: try row.string("name"),
            region: try row.string("region"),
            country: try row.string("country"),
            note: try row.string("note")
        )
    }

    static func rack(_ row: Row) throws -> Rack {
        Rack(
            id: try row.uuid("id"),
            name: try row.string("name"),
            rows: try row.int("rows"),
            columns: try row.int("columns"),
            sortOrder: try row.int("sort_order")
        )
    }

    static func cell(_ row: Row) throws -> Cell {
        Cell(
            id: try row.uuid("id"),
            rackID: try row.uuid("rack_id"),
            row: try row.int("row"),
            column: try row.int("column"),
            status: CellStatus(rawValue: try row.string("status")) ?? .empty,
            bottleID: row.optionalUUID("bottle_id")
        )
    }

    static func bottle(_ row: Row) throws -> Bottle {
        Bottle(
            id: try row.uuid("id"),
            producerID: row.optionalUUID("producer_id"),
            name: try row.string("name"),
            kind: BottleKind(rawValue: try row.string("kind")) ?? .wine,
            vintage: row.optionalInt("vintage"),
            grapeOrBase: try row.string("grape_or_base"),
            abvPercent: row.optionalDouble("abv_percent"),
            purchasedAt: row.optionalDate("purchased_at"),
            purchaseCents: try row.int("purchase_cents"),
            currencyCode: try row.string("currency_code"),
            peakStartYear: row.optionalInt("peak_start_year"),
            peakEndYear: row.optionalInt("peak_end_year"),
            cellarTempC: try row.double("cellar_temp_c"),
            note: try row.string("note"),
            drunkAt: row.optionalDate("drunk_at"),
            isArchived: try row.bool("is_archived")
        )
    }

    static func tasting(_ row: Row) throws -> Tasting {
        Tasting(
            id: try row.uuid("id"),
            bottleID: try row.uuid("bottle_id"),
            tastedAt: try row.date("tasted_at"),
            score: try row.int("score"),
            nose: try row.string("nose"),
            palate: try row.string("palate"),
            finish: try row.string("finish"),
            note: try row.string("note")
        )
    }

    static func purchase(_ row: Row) throws -> Purchase {
        Purchase(
            id: try row.uuid("id"),
            bottleID: try row.uuid("bottle_id"),
            purchasedAt: try row.date("purchased_at"),
            storeName: try row.string("store_name"),
            cents: try row.int("cents"),
            quantity: try row.int("quantity")
        )
    }
}
