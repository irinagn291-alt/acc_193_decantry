import Foundation

enum DecantDefaults {
    static let onboardingCompleted = "decantry.onboardingCompleted"
    static let seedVersion = "decantry.seedVersion"
}

enum DecantPaths {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var backupsDirectory: URL {
        documents.appendingPathComponent("Backups", isDirectory: true)
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    }
}

enum DecantMoney {
    nonisolated(unsafe) static var currencyCode = "USD"

    static func cents(_ value: Int) -> String {
        let amount = Double(value) / 100.0
        return String(format: "%.2f %@", amount, currencyCode)
    }

    /// Short ledger label for tight tiles (`$430`, `€1.2k`).
    static func compact(_ value: Int) -> String {
        let amount = Double(value) / 100.0
        let symbol: String = {
            switch currencyCode.uppercased() {
            case "USD": return "$"
            case "EUR": return "€"
            case "GBP": return "£"
            default: return ""
            }
        }()
        if abs(amount) >= 10_000 {
            return String(format: "%@%.1fk", symbol, amount / 1_000)
        }
        if amount.rounded() == amount {
            return String(format: "%@%.0f", symbol, amount)
        }
        return String(format: "%@%.0f", symbol, amount.rounded())
    }

    static func decimal(from string: String) -> Double? {
        let cleaned = string.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    static func cents(from string: String) -> Int {
        guard let value = decimal(from: string) else { return 0 }
        return Int((value * 100).rounded())
    }
}
