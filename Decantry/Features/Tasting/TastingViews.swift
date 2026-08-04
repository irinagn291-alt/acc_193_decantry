import SwiftUI

struct TastingListView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State private var tastings: [Tasting] = []
    @State private var bottleNames: [UUID: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if tastings.isEmpty {
                    DecantChrome.panel {
                        DecantEmpty.Panel(
                            image: .emptyTastings,
                            title: "No tastings",
                            message: "Tasting notes appear here after you log them on a bottle.",
                            systemImage: "note.text"
                        )
                    }
                } else {
                    ForEach(tastings) { tasting in
                        NavigationLink {
                            TastingEditorView(bottleID: tasting.bottleID, tasting: tasting)
                        } label: {
                            tastingRow(tasting)
                        }
                        .buttonStyle(DecantPressStyle())
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Tastings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func tastingRow(_ tasting: Tasting) -> some View {
        HStack(spacing: 14) {
            Text(verbatim: "\(tasting.score)")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(palette.brass)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(bottleNames[tasting.bottleID] ?? "Bottle")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.text)
                Text(tasting.tastedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
                if !tasting.nose.isEmpty || !tasting.palate.isEmpty {
                    Text([tasting.nose, tasting.palate].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.brass.opacity(0.5))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.surface.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(palette.brass.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private func load() async {
        tastings = (try? await environment.tastings.all()) ?? []
        let bottles = (try? await environment.bottles.all()) ?? []
        bottleNames = Dictionary(uniqueKeysWithValues: bottles.map { ($0.id, $0.name) })
    }
}

struct TastingEditorView: View {
    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment

    let bottleID: UUID
    let tasting: Tasting?

    @State private var tastedAt = Date()
    @State private var score = 85
    @State private var nose = ""
    @State private var palate = ""
    @State private var finish = ""
    @State private var note = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DecantChrome.SettingsBlock(title: "Session") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TASTED")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .tracking(1.6)
                                .foregroundStyle(palette.secondaryText)
                            DatePicker("", selection: $tastedAt, displayedComponents: .date)
                                .labelsHidden()
                                .tint(palette.brass)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("SCORE")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .tracking(1.6)
                                .foregroundStyle(palette.secondaryText)
                            HStack {
                                Text(verbatim: "\(score)")
                                    .font(.system(size: 32, weight: .semibold, design: .serif))
                                    .foregroundStyle(palette.brass)
                                Spacer()
                                Stepper("", value: $score, in: 0...100)
                                    .labelsHidden()
                                    .tint(palette.brass)
                            }
                        }
                    }
                }

                DecantChrome.SettingsBlock(title: "Notes") {
                    VStack(alignment: .leading, spacing: 8) {
                        DecantChrome.LedgerField(label: "Nose", text: $nose, axis: .vertical)
                        DecantChrome.LedgerField(label: "Palate", text: $palate, axis: .vertical)
                        DecantChrome.LedgerField(label: "Finish", text: $finish, axis: .vertical)
                        DecantChrome.LedgerField(label: "Note", text: $note, axis: .vertical)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(palette.wine)
                }

                DecantChrome.primaryButton("Save") { Task { await save() } }

                if tasting != nil {
                    Button("Delete tasting") { Task { await deleteTasting() } }
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(palette.wine)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { DecantAtmosphere() }
        .navigationTitle(tasting == nil ? "New tasting" : "Edit tasting")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let tasting {
                tastedAt = tasting.tastedAt
                score = tasting.score
                nose = tasting.nose
                palate = tasting.palate
                finish = tasting.finish
                note = tasting.note
            }
        }
    }

    private func save() async {
        let record = Tasting(
            id: tasting?.id ?? UUID(),
            bottleID: bottleID,
            tastedAt: tastedAt,
            score: score,
            nose: nose,
            palate: palate,
            finish: finish,
            note: note
        )
        do {
            try await environment.tastings.upsert(record)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTasting() async {
        guard let tasting else { return }
        try? await environment.tastings.delete(id: tasting.id)
        dismiss()
    }
}

struct ProducerListView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State private var producers: [Producer] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if producers.isEmpty {
                    DecantChrome.panel {
                        DecantEmpty.Panel(
                            image: .emptyCellar,
                            title: "No producers",
                            message: "Add producers when you catalog bottles from a house or estate.",
                            systemImage: "leaf"
                        )
                    }
                } else {
                    ForEach(producers) { producer in
                        NavigationLink {
                            ProducerDetailView(producer: producer)
                        } label: {
                            producerRow(producer)
                        }
                        .buttonStyle(DecantPressStyle())
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { DecantAtmosphere() }
        .navigationTitle("Producers")
        .navigationBarTitleDisplayMode(.inline)
        .task { producers = (try? await environment.producers.all()) ?? [] }
    }

    private func producerRow(_ producer: Producer) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 18))
                .foregroundStyle(palette.brass.opacity(0.75))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(producer.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.text)
                Text("\(producer.region), \(producer.country)")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.brass.opacity(0.5))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.surface.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(palette.brass.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

struct ProducerDetailView: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment
    @State var producer: Producer
    @State private var bottles: [Bottle] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DecantChrome.SettingsBlock(title: "Producer") {
                    VStack(alignment: .leading, spacing: 8) {
                        DecantChrome.LedgerField(label: "Name", text: $producer.name)
                        DecantChrome.LedgerField(label: "Region", text: $producer.region)
                        DecantChrome.LedgerField(label: "Country", text: $producer.country)
                        DecantChrome.LedgerField(label: "Note", text: $producer.note, axis: .vertical)
                        DecantChrome.primaryButton("Save producer") {
                            Task { try? await environment.producers.upsert(producer) }
                        }
                    }
                }

                DecantChrome.SettingsBlock(title: "Bottles") {
                    if bottles.isEmpty {
                        Text("No bottles linked to this producer.")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(bottles) { bottle in
                                NavigationLink(value: bottle) {
                                    HStack {
                                        Text(bottle.name)
                                            .font(.system(size: 16, weight: .medium, design: .serif))
                                            .foregroundStyle(palette.text)
                                        Spacer()
                                        if let vintage = bottle.vintage {
                                            Text(String(vintage))
                                                .font(DecantTokens.monoFont(.caption))
                                                .foregroundStyle(palette.secondaryText)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(palette.brass.opacity(0.5))
                                    }
                                }
                                .buttonStyle(DecantPressStyle())
                                if bottle.id != bottles.last?.id {
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
        .navigationTitle(producer.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Bottle.self) { BottleDetailView(bottleID: $0.id) }
        .task {
            let all = (try? await environment.bottles.all()) ?? []
            bottles = all.filter { $0.producerID == producer.id }
        }
    }
}
