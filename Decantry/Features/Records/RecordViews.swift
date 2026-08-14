import SwiftUI
import UniformTypeIdentifiers

struct LedgerView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State private var purchases: [Purchase] = []
    @State private var bottleNames: [UUID: String] = [:]
    @State private var averages: [(UUID, Int)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if purchases.isEmpty {
                    DecantChrome.panel {
                        DecantEmpty.Panel(
                            image: .emptyLedger,
                            title: "No purchases",
                            message: "Purchase records show cost per bottle and tasting averages.",
                            systemImage: "dollarsign.circle"
                        )
                    }
                } else {
                    if !averages.isEmpty {
                        DecantChrome.SettingsBlock(title: "Cost per tasting") {
                            VStack(spacing: 10) {
                                ForEach(averages, id: \.0) { pair in
                                    HStack {
                                        Text(bottleNames[pair.0] ?? "Bottle")
                                            .font(.system(size: 16, weight: .medium, design: .serif))
                                            .foregroundStyle(palette.text)
                                        Spacer()
                                        Text(DecantMoney.cents(pair.1))
                                            .font(DecantTokens.monoFont())
                                            .foregroundStyle(palette.brass)
                                    }
                                    if pair.0 != averages.last?.0 {
                                        Rectangle()
                                            .fill(palette.divider.opacity(0.6))
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }

                    DecantChrome.SettingsBlock(title: "Purchases") {
                        VStack(spacing: 10) {
                            ForEach(purchases) { purchase in
                                NavigationLink {
                                    BottleDetailView(bottleID: purchase.bottleID)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(bottleNames[purchase.bottleID] ?? purchase.storeName)
                                                .font(.system(size: 16, weight: .medium, design: .serif))
                                                .foregroundStyle(palette.text)
                                            Text(purchase.storeName)
                                                .font(.system(size: 12, design: .serif))
                                                .foregroundStyle(palette.secondaryText)
                                        }
                                        Spacer()
                                        Text(DecantMoney.cents(purchase.cents))
                                            .font(DecantTokens.monoFont())
                                            .foregroundStyle(palette.brass)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(palette.brass.opacity(0.5))
                                    }
                                }
                                .buttonStyle(DecantPressStyle())
                                if purchase.id != purchases.last?.id {
                                    Rectangle()
                                        .fill(palette.divider.opacity(0.6))
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Ledger")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        purchases = (try? await environment.purchases.all()) ?? []
        let bottles = (try? await environment.bottles.all()) ?? []
        bottleNames = Dictionary(uniqueKeysWithValues: bottles.map { ($0.id, $0.name) })
        averages = []
        for bottle in bottles where bottle.purchaseCents > 0 {
            let count = (try? await environment.tastings.count(forBottle: bottle.id)) ?? 0
            let avg = DrinkingWindowCalculator.averageCostPerTasting(purchaseCents: bottle.purchaseCents, tastingCount: count)
            if count == 0 && bottle.purchaseCents > 3000 {
                averages.append((bottle.id, avg))
            } else if count > 0 {
                averages.append((bottle.id, avg))
            }
        }
    }
}

struct DecantInsightsView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State private var histogram: [(MaturityStage, Int)] = []
    @State private var deadStock: [Bottle] = []

    private var histogramMax: Int {
        max(histogram.map(\.1).max() ?? 1, 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DecantChrome.SettingsBlock(title: "Window histogram") {
                    VStack(spacing: 12) {
                        ForEach(histogram, id: \.0) { item in
                            HStack(spacing: 12) {
                                Text(item.0.title)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(DecantTokens.stageColor(item.0))
                                    .frame(width: 88, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(palette.divider.opacity(0.7))
                                        Capsule()
                                            .fill(DecantTokens.stageColor(item.0).opacity(0.85))
                                            .frame(width: max(6, geo.size.width * CGFloat(item.1) / CGFloat(histogramMax)))
                                    }
                                }
                                .frame(height: 8)
                                Text("\(item.1)")
                                    .font(DecantTokens.monoFont(.caption))
                                    .foregroundStyle(palette.text)
                                    .frame(width: 24, alignment: .trailing)
                            }
                        }
                    }
                }

                DecantChrome.SettingsBlock(title: "High cost, zero tastings") {
                    if deadStock.isEmpty {
                        Text("No dead stock flagged")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(deadStock) { bottle in
                                NavigationLink(value: bottle) {
                                    HStack {
                                        Text(bottle.name)
                                            .font(.system(size: 16, weight: .medium, design: .serif))
                                            .foregroundStyle(palette.text)
                                        Spacer()
                                        Text(DecantMoney.cents(bottle.purchaseCents))
                                            .font(DecantTokens.monoFont())
                                            .foregroundStyle(palette.wine)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(palette.brass.opacity(0.5))
                                    }
                                }
                                .buttonStyle(DecantPressStyle())
                                if bottle.id != deadStock.last?.id {
                                    Rectangle()
                                        .fill(palette.divider.opacity(0.6))
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Bottle.self) { BottleDetailView(bottleID: $0.id) }
        .task { await load() }
    }

    private func load() async {
        let bottles = (try? await environment.bottles.all(activeOnly: true)) ?? []
        var counts: [MaturityStage: Int] = [:]
        for stage in MaturityStage.allCases { counts[stage] = 0 }
        deadStock = []
        for bottle in bottles {
            let stage = DrinkingWindowCalculator.window(for: bottle).stage
            counts[stage, default: 0] += 1
            let tastingCount = (try? await environment.tastings.count(forBottle: bottle.id)) ?? 0
            if tastingCount == 0 && bottle.purchaseCents >= 3000 {
                deadStock.append(bottle)
            }
        }
        histogram = MaturityStage.allCases.map { ($0, counts[$0] ?? 0) }
    }
}

struct DecantBackupView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State private var message: String?
    @State private var showImporter = false
    @State private var shareURL: URL?
    @State private var isExporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DecantChrome.SettingsBlock(title: "Cellar backup") {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(palette.brass.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)

                        Text("Export opens the share sheet so you can save to Files or AirDrop. Import replaces the current cellar.")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        if let message {
                            Text(message)
                                .font(DecantTokens.captionFont())
                                .foregroundStyle(palette.brass)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        DecantChrome.primaryButton(isExporting ? "Exporting…" : "Export backup") {
                            exportBackup()
                        }
                        .disabled(isExporting)
                        DecantChrome.secondaryButton("Import backup", action: { showImporter = true })
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                DecantShareSheet(items: [shareURL])
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            Task {
                do {
                    let url = try result.get()
                    let data = try DecantFileIO.readSecurityScoped(url)
                    try await environment.backup.importJSON(data)
                    message = "Import completed."
                } catch {
                    message = error.localizedDescription
                }
            }
        }
    }

    private func exportBackup() {
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                let data = try await environment.backup.exportJSON()
                let stamp = Int(Date().timeIntervalSince1970)
                let url = try DecantFileIO.writeTempJSON(data, name: "decantry-backup-\(stamp).json")
                _ = try? await environment.backup.writeBackupFile()
                shareURL = url
                message = "Choose Save to Files or AirDrop."
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

struct DecantSettingsView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State private var displayName = ""
    @State private var temp = ""
    @State private var currency = ""
    @State private var isShowingContactUs = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DecantChrome.SettingsBlock(title: "Profile") {
                    VStack(alignment: .leading, spacing: 14) {
                        DecantChrome.LedgerField(label: "Display name", text: $displayName)
                        DecantChrome.LedgerField(label: "Default temp", text: $temp, keyboard: .decimalPad, suffix: "°C")
                        DecantChrome.LedgerField(label: "Currency", text: $currency)
                        DecantChrome.primaryButton("Save profile") { Task { await saveProfile() } }
                    }
                }

                DecantChrome.SettingsBlock(title: "Storage") {
                    HStack {
                        Text("Database")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                        Spacer()
                        Text(byteLabel(environment.storeFileSize()))
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.text)
                    }
                }

                DecantChrome.SettingsBlock(title: "About") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Decantry — offline home cellar desk.")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        DecantChrome.primaryButton("Contact Us") { isShowingContactUs = true }
                    }
                }

                DecantChrome.SettingsBlock(title: "Backup") {
                    NavigationLink {
                        DecantBackupView()
                    } label: {
                        HStack {
                            Text("Export / import cellar")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(palette.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.brass.opacity(0.6))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(DecantPressStyle())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingContactUs) {
            NavigationStack {
                ContactUsWebView()
            }
        }
        .onAppear {
            if let profile = environment.cellarProfile {
                displayName = profile.displayName
                temp = String(profile.defaultTempC)
                currency = profile.currencyCode
            }
        }
    }

    private func byteLabel(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    private func saveProfile() async {
        guard let existing = environment.cellarProfile else { return }
        let profile = CellarProfile(
            id: existing.id,
            displayName: displayName,
            defaultTempC: Double(temp) ?? existing.defaultTempC,
            currencyCode: currency.uppercased()
        )
        try? await environment.profile.upsert(profile)
        await environment.reloadProfile()
    }
}
