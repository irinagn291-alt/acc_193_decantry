import SwiftUI

struct BottleDetailView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    let bottleID: UUID

    @State private var bottle: Bottle?
    @State private var tastings: [Tasting] = []
    @State private var producerName = ""
    @State private var showEditor = false
    @State private var showTasting = false

    var body: some View {
        Group {
            if let bottle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        maturityHero(bottle)
                        factsGrid(bottle)
                        if !bottle.note.isEmpty, bottle.note != "Simulator demo bottle." {
                            noteBlock(bottle.note)
                        }
                        actionsRow
                        tastingsBlock
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            } else {
                ProgressView()
                    .tint(palette.brass)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background { DecantAtmosphere() }
        .navigationTitle(bottle?.name ?? "Bottle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            if let bottle {
                NavigationStack {
                    EditBottleView(bottle: bottle)
                }
                .environmentObject(environment)
            }
        }
        .sheet(isPresented: $showTasting) {
            if let bottle {
                NavigationStack {
                    TastingEditorView(bottleID: bottle.id, tasting: nil)
                }
                .environmentObject(environment)
            }
        }
        .task { await load() }
        .onChange(of: showEditor) { open in
            if !open { Task { await load() } }
        }
        .onChange(of: showTasting) { open in
            if !open { Task { await load() } }
        }
    }

    private func maturityHero(_ bottle: Bottle) -> some View {
        let window = DrinkingWindowCalculator.window(for: bottle)
        let stageColor = DecantTokens.stageColor(window.stage)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bottle.name)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if !producerName.isEmpty {
                        Text(producerName)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                Spacer(minLength: 12)
                DecantChrome.MaturityChip(stage: window.stage)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.divider.opacity(0.8))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [stageColor.opacity(0.55), stageColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(18, geo.size.width * maturityProgress(window)))
                }
            }
            .frame(height: 6)

            HStack {
                Label {
                    Text("Peak \(window.peakLabel)")
                        .font(.system(size: 13, design: .monospaced))
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption)
                }
                .foregroundStyle(palette.secondaryText)

                Spacer()

                if let days = window.remainingDays {
                    Text(daysLabel(days))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(days < 0 ? palette.wine : palette.brass)
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.surface.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(stageColor.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private func factsGrid(_ bottle: Bottle) -> some View {
        let items: [(String, String)] = [
            ("Vintage", bottle.vintage.map { String($0) } ?? "—"),
            ("Paid", DecantMoney.compact(bottle.purchaseCents)),
            ("Grape", bottle.grapeOrBase.isEmpty ? "—" : bottle.grapeOrBase),
            ("Kind", bottle.kind.rawValue.capitalized)
        ]

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.0.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .tracking(1.2)
                        .foregroundStyle(palette.brass)
                    Text(item.1)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.surface.opacity(0.9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(palette.brass.opacity(0.18), lineWidth: 1)
                        }
                }
            }
        }
    }

    private func noteBlock(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTE")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundStyle(palette.brass)
            Text(note)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.surface.opacity(0.75))
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            actionButton("Edit", systemImage: "pencil") { showEditor = true }
            actionButton("Tasting", systemImage: "note.text.badge.plus") { showTasting = true }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.wine.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.brass.opacity(0.35), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(DecantPressStyle())
    }

    private var tastingsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            DecantChrome.SectionHeader(
                title: "Tastings",
                detail: tastings.isEmpty ? "No notes yet" : "\(tastings.count) logged"
            )

            if tastings.isEmpty {
                Text("Add a tasting when you open this bottle.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(palette.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.brass.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
            } else {
                VStack(spacing: 8) {
                    ForEach(tastings) { tasting in
                        NavigationLink {
                            TastingEditorView(bottleID: bottleID, tasting: tasting)
                        } label: {
                            HStack(spacing: 12) {
                                Text(verbatim: "\(tasting.score)")
                                    .font(.system(size: 22, weight: .bold, design: .serif))
                                    .foregroundStyle(palette.brass)
                                    .frame(width: 40, alignment: .leading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tasting.tastedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 15, weight: .medium, design: .serif))
                                        .foregroundStyle(palette.text)
                                    Text([tasting.nose, tasting.palate].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.system(size: 12, design: .serif))
                                        .foregroundStyle(palette.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.brass.opacity(0.5))
                            }
                            .padding(14)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(palette.surface.opacity(0.9))
                            }
                        }
                        .buttonStyle(DecantPressStyle())
                    }
                }
            }
        }
    }

    private func maturityProgress(_ window: BottleWindow) -> CGFloat {
        switch window.stage {
        case .young: return 0.18
        case .approaching: return 0.38
        case .ready: return 0.72
        case .holding: return 0.88
        case .pastPeak: return 1.0
        }
    }

    private func daysLabel(_ days: Int) -> String {
        if days > 0 { return "\(days)d left" }
        if days == 0 { return "Peak edge" }
        return "\(abs(days))d past"
    }

    private func load() async {
        bottle = try? await environment.bottles.fetch(id: bottleID)
        tastings = (try? await environment.tastings.forBottle(bottleID)) ?? []
        if let pid = bottle?.producerID, let producer = try? await environment.producers.fetch(id: pid) {
            producerName = producer.name
        } else {
            producerName = ""
        }
    }
}

struct EditBottleView: View {
    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment

    @State var bottle: Bottle
    @State private var purchaseText = ""
    @State private var vintageText = ""
    @State private var peakStartText = ""
    @State private var peakEndText = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DecantChrome.LedgerField(label: "Name", text: $bottle.name)
                DecantChrome.LedgerField(label: "Grape or base", text: $bottle.grapeOrBase)
                DecantChrome.LedgerField(label: "Vintage", text: $vintageText, keyboard: .numberPad)
                DecantChrome.LedgerField(label: "Purchase", text: $purchaseText, keyboard: .decimalPad, suffix: DecantMoney.currencyCode)
                DecantChrome.LedgerField(label: "Peak start", text: $peakStartText, keyboard: .numberPad)
                DecantChrome.LedgerField(label: "Peak end", text: $peakEndText, keyboard: .numberPad)
                DecantChrome.LedgerField(label: "Note", text: $bottle.note)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(palette.wine)
                }
                DecantChrome.primaryButton("Save") { Task { await save() } }
            }
            .padding(20)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Edit bottle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .foregroundStyle(palette.brass)
            }
        }
        .onAppear {
            purchaseText = String(format: "%.2f", Double(bottle.purchaseCents) / 100)
            vintageText = bottle.vintage.map(String.init) ?? ""
            peakStartText = bottle.peakStartYear.map(String.init) ?? ""
            peakEndText = bottle.peakEndYear.map(String.init) ?? ""
        }
    }

    private func save() async {
        bottle.purchaseCents = DecantMoney.cents(from: purchaseText)
        bottle.vintage = Int(vintageText)
        bottle.peakStartYear = Int(peakStartText)
        bottle.peakEndYear = Int(peakEndText)
        do {
            try await environment.bottles.upsert(bottle)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PlaceBottleView: View {
    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    let rack: Rack
    let cell: Cell

    @State private var name = ""
    @State private var vintage = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Seat \(coordinate)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.brass)
                DecantChrome.LedgerField(label: "Bottle name", text: $name)
                DecantChrome.LedgerField(label: "Vintage", text: $vintage, keyboard: .numberPad)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(palette.wine)
                }
                DecantChrome.primaryButton("Place bottle") { Task { await place() } }
            }
            .padding(20)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Place bottle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .foregroundStyle(palette.brass)
            }
        }
    }

    private var coordinate: String {
        let row = Character(UnicodeScalar(65 + min(cell.row, 25))!)
        return "\(row)\(cell.column + 1)"
    }

    private func place() async {
        let profile = environment.cellarProfile
        let bottle = Bottle(
            id: UUID(),
            producerID: nil,
            name: name,
            kind: .wine,
            vintage: Int(vintage),
            grapeOrBase: "",
            abvPercent: nil,
            purchasedAt: .now,
            purchaseCents: 0,
            currencyCode: profile?.currencyCode ?? "USD",
            peakStartYear: nil,
            peakEndYear: nil,
            cellarTempC: profile?.defaultTempC ?? 13,
            note: "",
            drunkAt: nil,
            isArchived: false
        )
        do {
            try await environment.bottles.upsert(bottle)
            try await environment.cells.upsert(
                Cell(id: cell.id, rackID: rack.id, row: cell.row, column: cell.column, status: .occupied, bottleID: bottle.id)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DrinkNextView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State private var bottles: [Bottle] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DecantChrome.HeroBanner(
                    image: .drinkNextBanner,
                    eyebrow: "Window",
                    title: "Drink next",
                    subtitle: bottles.isEmpty
                        ? "Nothing urgent this week"
                        : "\(bottles.count) bottles near the edge"
                )

                if bottles.isEmpty {
                    Text("No bottles are closing their window this week.")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(palette.secondaryText)
                        .padding(16)
                } else {
                    ForEach(bottles) { bottle in
                        NavigationLink(value: bottle) {
                            let window = DrinkingWindowCalculator.window(for: bottle)
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(DecantTokens.stageColor(window.stage))
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bottle.name)
                                        .font(.system(size: 17, weight: .semibold, design: .serif))
                                        .foregroundStyle(palette.text)
                                    Text(window.peakLabel)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(palette.secondaryText)
                                }
                                Spacer()
                                DecantChrome.MaturityChip(stage: window.stage)
                            }
                            .padding(14)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(palette.surface.opacity(0.9))
                            }
                        }
                        .buttonStyle(DecantPressStyle())
                    }
                }
            }
            .padding(20)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Drink next")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Bottle.self) { BottleDetailView(bottleID: $0.id) }
        .task { await load() }
    }

    private func load() async {
        let all = (try? await environment.bottles.all(activeOnly: true)) ?? []
        bottles = DrinkingWindowCalculator.closingThisWeek(bottles: all)
    }
}
