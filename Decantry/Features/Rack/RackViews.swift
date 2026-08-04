import SwiftUI

@MainActor
final class RackWallViewModel: ObservableObject {
    @Published var racks: [Rack] = []
    @Published var bottles: [Bottle] = []
    @Published var selectedBottleID: UUID?
    @Published var errorMessage: String?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        do {
            racks = try await environment.racks.all()
            bottles = try await environment.bottles.all(activeOnly: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func window(for bottle: Bottle) -> BottleWindow {
        DrinkingWindowCalculator.window(for: bottle)
    }

    func closingSoon() -> [Bottle] {
        DrinkingWindowCalculator.closingThisWeek(bottles: bottles)
    }

    func drinkNext(limit: Int = 4) -> [Bottle] {
        let ranked = bottles.sorted { lhs, rhs in
            let l = window(for: lhs)
            let r = window(for: rhs)
            let lReady = l.stage == .ready || l.stage == .holding || l.stage == .pastPeak
            let rReady = r.stage == .ready || r.stage == .holding || r.stage == .pastPeak
            if lReady != rReady { return lReady && !rReady }
            let lDays = l.remainingDays ?? Int.max
            let rDays = r.remainingDays ?? Int.max
            return lDays < rDays
        }
        return Array(ranked.prefix(limit))
    }

    func stageCounts() -> [(MaturityStage, Int)] {
        var counts: [MaturityStage: Int] = [:]
        for bottle in bottles {
            counts[window(for: bottle).stage, default: 0] += 1
        }
        return MaturityStage.allCases.compactMap { stage in
            guard let count = counts[stage], count > 0 else { return nil }
            return (stage, count)
        }
    }

    var ledgerCents: Int {
        bottles.reduce(0) { $0 + $1.purchaseCents }
    }
}

struct RackWallHubView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var holder = DecantVMBox<RackWallViewModel>()
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if let vm = holder.value {
                RackDashboardContent(vm: vm, columnVisibility: $columnVisibility)
            } else {
                ProgressView()
                    .tint(ThemePalette.decantry.brass)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { DecantAtmosphere() }
            }
        }
        .onAppear {
            if holder.value == nil {
                holder.value = RackWallViewModel(environment: environment)
            }
        }
        .task { await holder.value?.load() }
    }
}

private struct RackDashboardContent: View {
    @ObservedObject var vm: RackWallViewModel
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.themePalette) private var palette
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    dashboardScroll
                } detail: {
                    bottleDetailColumn
                }
            } else {
                NavigationStack {
                    dashboardScroll
                }
            }
        }
    }

    private var dashboardScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                DecantChrome.HeroBanner(
                    image: .rackBanner,
                    eyebrow: "House wall",
                    title: environment.cellarProfile?.displayName ?? "Decantry",
                    subtitle: "\(vm.bottles.count) bottles · \(vm.closingSoon().count) closing soon"
                )

                metricsRow

                if !vm.drinkNext().isEmpty {
                    drinkNextSection
                }

                if let rack = vm.racks.first {
                    rackPreview(rack)
                } else {
                    emptyRacks
                }

                deskShortcuts
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .background { DecantAtmosphere() }
        .navigationTitle("Cellar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DecantSettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(palette.brass)
                }
            }
        }
        .navigationDestination(for: Rack.self) { rack in
            RackDetailView(rack: rack, selectedBottleID: bindingSelectedBottle)
        }
        .navigationDestination(for: Bottle.self) { bottle in
            BottleDetailView(bottleID: bottle.id)
        }
        .refreshable { await vm.load() }
    }

    private var metricsRow: some View {
        HStack(alignment: .top, spacing: 8) {
            metricTile(title: "Bottles", value: "\(vm.bottles.count)")
            metricTile(title: "Racks", value: "\(vm.racks.count)")
            metricTile(title: "Ledger", value: DecantMoney.compact(vm.ledgerCents))
        }
        .frame(height: 78)
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundStyle(palette.brass)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(palette.surface.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(palette.brass.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var drinkNextSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DecantChrome.SectionHeader(
                    title: "Drink next",
                    detail: "Bottles nearest their window"
                )
                Spacer(minLength: 8)
                NavigationLink {
                    DrinkNextView()
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(palette.brass)
                }
                .buttonStyle(DecantPressStyle())
            }

            VStack(spacing: 10) {
                ForEach(vm.drinkNext()) { bottle in
                    NavigationLink(value: bottle) {
                        drinkRow(bottle)
                    }
                    .buttonStyle(DecantPressStyle())
                }
            }
        }
    }

    private func drinkRow(_ bottle: Bottle) -> some View {
        let window = vm.window(for: bottle)
        return HStack(spacing: 14) {
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
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.brass.opacity(0.55))
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(palette.surface.opacity(0.88))
        }
    }

    private func rackPreview(_ rack: Rack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DecantChrome.SectionHeader(
                    title: rack.name,
                    detail: "\(rack.rows)×\(rack.columns) wall · tap a cell"
                )
                Spacer()
                NavigationLink(value: rack) {
                    Text("Open")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(palette.brass)
                }
                .buttonStyle(DecantPressStyle())
            }

            NavigationLink(value: rack) {
                HubRackPreview(rack: rack)
            }
            .buttonStyle(DecantPressStyle())

            if vm.racks.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.racks.dropFirst()) { extra in
                            NavigationLink(value: extra) {
                                Text(extra.name)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(palette.text)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 4))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(palette.brass.opacity(0.25), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(DecantPressStyle())
                        }
                    }
                }
            }
        }
    }

    private var emptyRacks: some View {
        VStack(alignment: .leading, spacing: 16) {
            DecantChrome.SectionHeader(title: "Racks", detail: "Map bottles to a wall")
            DecantChrome.primaryButton("Add rack") {
                Task { await addRack() }
            }
        }
    }

    private var deskShortcuts: some View {
        VStack(alignment: .leading, spacing: 14) {
            DecantChrome.SectionHeader(title: "Cellar desk", detail: "Notes, producers, money")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                deskTile("Tastings", systemImage: "note.text", destination: TastingListView())
                deskTile("Producers", systemImage: "leaf", destination: ProducerListView())
                deskTile("Ledger", systemImage: "dollarsign.circle", destination: LedgerView())
                deskTile("Insights", systemImage: "chart.bar", destination: DecantInsightsView())
            }
        }
    }

    private func deskTile<V: View>(_ title: String, systemImage: String, destination: V) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.brass)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(palette.text)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.surface.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(palette.brass.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(DecantPressStyle())
    }

    @ViewBuilder
    private var bottleDetailColumn: some View {
        if let id = vm.selectedBottleID {
            BottleDetailView(bottleID: id)
        } else {
            Text("Select a bottle")
                .font(DecantTokens.bodyFont())
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { DecantAtmosphere() }
        }
    }

    private var bindingSelectedBottle: Binding<UUID?> {
        Binding(
            get: { vm.selectedBottleID },
            set: { vm.selectedBottleID = $0 }
        )
    }

    private func addRack() async {
        let rack = Rack(id: UUID(), name: "Rack \(vm.racks.count + 1)", rows: 3, columns: 4, sortOrder: 0)
        try? await environment.racks.upsert(rack)
        try? await environment.cells.createGrid(for: rack)
        await vm.load()
    }
}

private struct HubRackPreview: View {
    @EnvironmentObject private var environment: AppEnvironment
    let rack: Rack

    @State private var cells: [Cell] = []
    @State private var bottles: [UUID: Bottle] = [:]

    var body: some View {
        RackWallBoard(rack: rack, cells: cells, bottles: bottles, compact: true) { _, _ in }
            .task { await load() }
    }

    private func load() async {
        cells = (try? await environment.cells.cells(forRack: rack.id)) ?? []
        let all = (try? await environment.bottles.all(activeOnly: true)) ?? []
        bottles = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }
}

struct RackDetailView: View {
    @Environment(\.themePalette) private var palette
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var environment: AppEnvironment
    let rack: Rack
    @Binding var selectedBottleID: UUID?

    @State private var cells: [Cell] = []
    @State private var bottles: [UUID: Bottle] = [:]
    @State private var placeTarget: Cell?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(rack.rows)×\(rack.columns)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.brass)
                    Spacer()
                    Text("\(occupiedCount) seated")
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(palette.secondaryText)
                }

                RackWallBoard(rack: rack, cells: cells, bottles: bottles, compact: false) { cell, bottle in
                    if let bottle {
                        if sizeClass == .regular {
                            selectedBottleID = bottle.id
                        }
                    } else {
                        placeTarget = cell
                    }
                }

                if !legendStages.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(legendStages, id: \.self) { stage in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(DecantTokens.stageColor(stage))
                                    .frame(width: 7, height: 7)
                                Text(stage.title)
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundStyle(palette.secondaryText)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background { DecantAtmosphere() }
        .navigationTitle(rack.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Bottle.self) { bottle in
            BottleDetailView(bottleID: bottle.id)
        }
        .sheet(item: $placeTarget) { cell in
            NavigationStack {
                PlaceBottleView(rack: rack, cell: cell)
            }
            .environmentObject(environment)
        }
        .task { await load() }
        .onChange(of: placeTarget) { target in
            guard target == nil else { return }
            Task { await load() }
        }
    }

    private var occupiedCount: Int {
        cells.filter { $0.bottleID != nil }.count
    }

    private var legendStages: [MaturityStage] {
        var seen = Set<MaturityStage>()
        var ordered: [MaturityStage] = []
        for cell in cells {
            guard let id = cell.bottleID, let bottle = bottles[id] else { continue }
            let stage = DrinkingWindowCalculator.window(for: bottle).stage
            if seen.insert(stage).inserted {
                ordered.append(stage)
            }
        }
        return ordered
    }

    private func load() async {
        cells = (try? await environment.cells.cells(forRack: rack.id)) ?? []
        let all = (try? await environment.bottles.all(activeOnly: true)) ?? []
        bottles = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }
}

/// Oak-framed wall of bottle niches — equal cells, short labels.
private struct RackWallBoard: View {
    @Environment(\.themePalette) private var palette
    @Environment(\.horizontalSizeClass) private var sizeClass

    let rack: Rack
    let cells: [Cell]
    let bottles: [UUID: Bottle]
    var compact: Bool = false
    let onSelect: (Cell, Bottle?) -> Void

    var body: some View {
        let gap: CGFloat = compact ? 6 : 8
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: gap),
            count: max(1, rack.columns)
        )

        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(cells) { cell in
                niche(for: cell)
            }
        }
        .padding(compact ? 12 : 14)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x2A2218),
                            Color(hex: 0x1A1612),
                            Color(hex: 0x241C14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    palette.brass.opacity(0.45),
                                    palette.oak.opacity(0.25),
                                    palette.brass.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
        }
    }

    @ViewBuilder
    private func niche(for cell: Cell) -> some View {
        let bottle = cell.bottleID.flatMap { bottles[$0] }
        let stage = bottle.map { DrinkingWindowCalculator.window(for: $0).stage }

        Group {
            if let bottle, sizeClass != .regular, !compact {
                NavigationLink(value: bottle) {
                    RackNicheCell(
                        bottle: bottle,
                        stage: stage,
                        coordinate: coordinate(cell),
                        compact: compact
                    )
                }
                .buttonStyle(DecantPressStyle())
            } else {
                Button {
                    onSelect(cell, bottle)
                } label: {
                    RackNicheCell(
                        bottle: bottle,
                        stage: stage,
                        coordinate: coordinate(cell),
                        compact: compact
                    )
                }
                .buttonStyle(DecantPressStyle())
                .disabled(compact)
            }
        }
    }

    private func coordinate(_ cell: Cell) -> String {
        let row = Character(UnicodeScalar(65 + cell.row)!)
        return "\(row)\(cell.column + 1)"
    }
}

private struct RackNicheCell: View {
    @Environment(\.themePalette) private var palette
    let bottle: Bottle?
    let stage: MaturityStage?
    let coordinate: String
    var compact: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                .fill(Color.black.opacity(0.35))

            Capsule(style: .continuous)
                .fill(nicheFill)
                .padding(compact ? 7 : 10)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(palette.brass.opacity(bottle == nil ? 0.12 : 0.28), lineWidth: 1)
                        .padding(compact ? 7 : 10)
                }

            VStack(spacing: compact ? 2 : 4) {
                Text(coordinate)
                    .font(.system(size: compact ? 8 : 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.brass.opacity(0.7))

                if let bottle {
                    Text(shortName(bottle.name))
                        .font(.system(size: compact ? 9 : 12, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !compact, let vintage = bottle.vintage {
                        Text("\(vintage)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.secondaryText)
                    }
                } else if !compact {
                    Text("Open")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundStyle(palette.secondaryText.opacity(0.7))
                }
            }
            .padding(.horizontal, compact ? 4 : 6)
        }
        .aspectRatio(compact ? 0.85 : 0.78, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var nicheFill: LinearGradient {
        if let stage {
            return LinearGradient(
                colors: [
                    DecantTokens.stageColor(stage).opacity(0.95),
                    DecantTokens.stageColor(stage).opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(hex: 0x3A342C).opacity(0.9),
                Color(hex: 0x2A2620).opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func shortName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return parts.prefix(2).joined(separator: " ")
        }
        return name
    }
}
