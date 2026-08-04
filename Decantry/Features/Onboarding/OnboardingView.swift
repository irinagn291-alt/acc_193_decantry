import SwiftUI

@MainActor
final class DecantOnboardingViewModel: ObservableObject {
    @Published var displayName = "My Cellar"
    @Published var defaultTemp = "13"
    @Published var currencyCode = "USD"
    @Published var rackName = "Main Rack"
    @Published var rackRows = "3"
    @Published var rackColumns = "4"
    @Published var bottleName = "House Red"
    @Published var vintage = "2019"
    @Published var step = 0
    @Published var errorMessage: String?
    @Published var isWorking = false

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var canAdvance: Bool {
        switch step {
        case 0: !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: !rackName.isEmpty && (Int(rackRows) ?? 0) > 0 && (Int(rackColumns) ?? 0) > 0
        case 2: !bottleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: true
        }
    }

    func goBack() {
        guard step > 0 else { return }
        step -= 1
    }

    func goNext() {
        guard canAdvance, step < 2 else { return }
        step += 1
    }

    func finish() async -> Bool {
        guard canAdvance else { return false }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let profile = CellarProfile(
            id: UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultTempC: Double(defaultTemp) ?? 13,
            currencyCode: currencyCode.uppercased()
        )
        let rack = Rack(
            id: UUID(),
            name: rackName,
            rows: max(1, Int(rackRows) ?? 3),
            columns: max(1, Int(rackColumns) ?? 4),
            sortOrder: 0
        )
        let bottle = Bottle(
            id: UUID(),
            producerID: nil,
            name: bottleName.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: .wine,
            vintage: Int(vintage),
            grapeOrBase: "",
            abvPercent: nil,
            purchasedAt: .now,
            purchaseCents: 0,
            currencyCode: profile.currencyCode,
            peakStartYear: (Int(vintage) ?? 2019) + 6,
            peakEndYear: (Int(vintage) ?? 2019) + 10,
            cellarTempC: profile.defaultTempC,
            note: "",
            drunkAt: nil,
            isArchived: false
        )
        do {
            try await environment.profile.upsert(profile)
            try await environment.racks.upsert(rack)
            try await environment.cells.createGrid(for: rack)
            try await environment.bottles.upsert(bottle)
            let cells = try await environment.cells.cells(forRack: rack.id)
            if let first = cells.first {
                try await environment.cells.upsert(
                    Cell(id: first.id, rackID: rack.id, row: first.row, column: first.column, status: .occupied, bottleID: bottle.id)
                )
            }
            await environment.reloadProfile()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct DecantOnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment
    let onFinished: () -> Void

    @StateObject private var holder = DecantVMBox<DecantOnboardingViewModel>()

    var body: some View {
        ZStack {
            DecantAtmosphere()
            Group {
                if let vm = holder.value {
                    DecantOnboardingContent(vm: vm, onFinished: onFinished)
                } else {
                    ProgressView()
                        .tint(ThemePalette.decantry.brass)
                }
            }
        }
        .onAppear {
            if holder.value == nil {
                holder.value = DecantOnboardingViewModel(environment: environment)
            }
        }
    }
}

/// Separate view so `@ObservedObject` actually receives `step` / field publishes.
private struct DecantOnboardingContent: View {
    @Environment(\.themePalette) private var palette
    @ObservedObject var vm: DecantOnboardingViewModel
    let onFinished: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                hero(for: vm.step)
                DecantChrome.StepRail(current: vm.step, total: 3)
                    .padding(.horizontal, 4)

                DecantChrome.panel {
                    VStack(alignment: .leading, spacing: 22) {
                        stepCopy(vm.step)
                        stepFields
                    }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(palette.brass)
                }

                HStack(spacing: 16) {
                    if vm.step > 0 {
                        Button("Back") { vm.goBack() }
                            .buttonStyle(DecantPressStyle())
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundColor(palette.brass)
                    }
                    Spacer(minLength: 0)
                    if vm.step < 2 {
                        Button {
                            vm.goNext()
                        } label: {
                            Text("CONTINUE")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .tracking(2.2)
                                .foregroundColor(palette.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(palette.wine)
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .strokeBorder(palette.brass.opacity(0.45), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(DecantPressStyle())
                        .disabled(!vm.canAdvance || vm.isWorking)
                        .opacity(vm.canAdvance ? 1 : 0.45)
                        .frame(maxWidth: 220)
                    } else {
                        Button {
                            Task {
                                if await vm.finish() { onFinished() }
                            }
                        } label: {
                            Text(vm.isWorking ? "SAVING…" : "OPEN CELLAR")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .tracking(2.2)
                                .foregroundColor(palette.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(palette.wine)
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .strokeBorder(palette.brass.opacity(0.45), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(DecantPressStyle())
                        .disabled(!vm.canAdvance || vm.isWorking)
                        .opacity(vm.canAdvance ? 1 : 0.45)
                        .frame(maxWidth: 220)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func hero(for step: Int) -> some View {
        switch step {
        case 0:
            DecantChrome.HeroBanner(
                image: .onboardingProfile,
                eyebrow: "Step 01 — Profile",
                title: "Name the cellar",
                subtitle: "Temperature and currency live with the house style."
            )
        case 1:
            DecantChrome.HeroBanner(
                image: .onboardingRack,
                eyebrow: "Step 02 — Rack",
                title: "Build the first wall",
                subtitle: "Rows and columns become the bottle grid."
            )
        default:
            DecantChrome.HeroBanner(
                image: .onboardingBottle,
                eyebrow: "Step 03 — Bottle",
                title: "Seat a first bottle",
                subtitle: "Something to open when the window turns ready."
            )
        }
    }

    @ViewBuilder
    private func stepCopy(_ step: Int) -> some View {
        switch step {
        case 0:
            DecantChrome.SectionHeader(
                title: "Your cellar profile",
                detail: "Written like a cellar book — not a settings form."
            )
        case 1:
            DecantChrome.SectionHeader(
                title: "First rack",
                detail: "Keep it modest; you can add walls later."
            )
        default:
            DecantChrome.SectionHeader(
                title: "Sample bottle",
                detail: "Vintage feeds the drinking-window forecast."
            )
        }
    }

    @ViewBuilder
    private var stepFields: some View {
        switch vm.step {
        case 0:
            DecantChrome.LedgerField(label: "Display name", text: $vm.displayName)
            DecantChrome.LedgerField(label: "Cellar temperature", text: $vm.defaultTemp, keyboard: .decimalPad, suffix: "°C")
            DecantChrome.LedgerField(label: "Currency", text: $vm.currencyCode)
        case 1:
            DecantChrome.LedgerField(label: "Rack name", text: $vm.rackName)
            HStack(spacing: 20) {
                DecantChrome.LedgerField(label: "Rows", text: $vm.rackRows, keyboard: .numberPad)
                DecantChrome.LedgerField(label: "Columns", text: $vm.rackColumns, keyboard: .numberPad)
            }
        default:
            DecantChrome.LedgerField(label: "Bottle name", text: $vm.bottleName)
            DecantChrome.LedgerField(label: "Vintage", text: $vm.vintage, keyboard: .numberPad)
        }
    }
}
