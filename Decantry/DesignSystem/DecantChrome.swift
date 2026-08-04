import SwiftUI

/// Cellar ledger chrome — oak frames, brass rules, wine seals. No stock controls.
enum DecantChrome {
    // MARK: Surfaces

    static func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ThemePalette.decantry.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        ThemePalette.decantry.brass.opacity(0.55),
                                        ThemePalette.decantry.oak.opacity(0.2),
                                        ThemePalette.decantry.brass.opacity(0.35)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            }
    }

    // MARK: Buttons

    static func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .serif))
                .tracking(2.2)
                .foregroundColor(ThemePalette.decantry.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0x8A2438),
                                    ThemePalette.decantry.wine,
                                    Color(hex: 0x4A121C)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(ThemePalette.decantry.brass.opacity(0.45), lineWidth: 1)
                        )
                        .shadow(color: ThemePalette.decantry.wine.opacity(0.45), radius: 12, y: 6)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(DecantPressStyle())
    }

    static func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(ThemePalette.decantry.brass)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(DecantPressStyle())
    }

    // MARK: Fields

    struct LedgerField: View {
        let label: String
        @Binding var text: String
        var keyboard: UIKeyboardType = .default
        var suffix: String? = nil
        var axis: Axis = .horizontal

        @Environment(\.themePalette) private var palette
        @FocusState private var focused: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .tracking(1.6)
                    .foregroundStyle(focused ? palette.brass : palette.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("", text: $text, axis: axis)
                        .font(.system(size: axis == .vertical ? 16 : 22, weight: .regular, design: .serif))
                        .foregroundColor(palette.text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.words)
                        .lineLimit(axis == .vertical ? 3...8 : 1...1)
                        .focused($focused)
                        .tint(palette.brass)

                    if let suffix {
                        Text(suffix)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.oak)
                    }
                }
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: focused
                                    ? [palette.brass, palette.wine.opacity(0.6)]
                                    : [palette.divider, palette.oak.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: focused ? 1.5 : 1)
                }
            }
            .padding(.vertical, 6)
        }
    }

    struct SettingsBlock<Content: View>: View {
        let title: String
        @ViewBuilder let content: () -> Content

        @Environment(\.themePalette) private var palette

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(1.6)
                    .foregroundStyle(palette.brass)
                content()
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(palette.surface.opacity(0.92))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(palette.brass.opacity(0.2), lineWidth: 1)
                            }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Hero / headers

    /// Drawn cellar faceplate — `image` kept for call-site API compatibility.
    struct HeroBanner: View {
        let image: DecantImage
        let eyebrow: String
        let title: String
        let subtitle: String

        @Environment(\.themePalette) private var palette

        var body: some View {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color(hex: 0x2C2420),
                        palette.background,
                        Color(hex: 0x1A1218)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.wine.opacity(0.42), .clear],
                    center: .topTrailing,
                    startRadius: 16,
                    endRadius: 220
                )

                RadialGradient(
                    colors: [palette.oak.opacity(0.28), .clear],
                    center: .bottomLeading,
                    startRadius: 8,
                    endRadius: 200
                )

                Canvas { context, size in
                    for fraction in [0.24, 0.5, 0.76] as [CGFloat] {
                        var shelf = Path()
                        shelf.move(to: CGPoint(x: 14, y: size.height * fraction))
                        shelf.addLine(to: CGPoint(x: size.width - 14, y: size.height * fraction))
                        context.stroke(shelf, with: .color(palette.oak.opacity(0.22)), lineWidth: 1)
                    }

                    var x: CGFloat = size.width - 52
                    while x < size.width - 12 {
                        let tall = Int(x) % 18 < 6
                        let tickHeight: CGFloat = tall ? 16 : 7
                        var tick = Path()
                        tick.move(to: CGPoint(x: x, y: size.height * 0.18))
                        tick.addLine(to: CGPoint(x: x, y: size.height * 0.18 + tickHeight))
                        context.stroke(
                            tick,
                            with: .color(palette.brass.opacity(tall ? 0.4 : 0.16)),
                            lineWidth: 1
                        )
                        x += 9
                    }
                }

                Circle()
                    .strokeBorder(palette.brass.opacity(0.32), lineWidth: 1.5)
                    .frame(width: 96, height: 96)
                    .offset(x: 28, y: -52)

                Circle()
                    .fill(palette.wine.opacity(0.14))
                    .frame(width: 140, height: 140)
                    .offset(x: -24, y: 48)

                LinearGradient(
                    colors: [.clear, palette.background.opacity(0.4), palette.background.opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .tracking(2.4)
                        .foregroundStyle(palette.brass)
                    Text(title)
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                palette.brass.opacity(0.45),
                                palette.oak.opacity(0.2),
                                palette.brass.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .accessibilityLabel("\(eyebrow). \(title). \(subtitle)")
        }
    }

    struct StepRail: View {
        let current: Int
        let total: Int
        @Environment(\.themePalette) private var palette

        var body: some View {
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index <= current ? palette.brass : palette.divider)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    struct SectionHeader: View {
        let title: String
        var detail: String? = nil
        @Environment(\.themePalette) private var palette

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.text)
                if let detail {
                    Text(detail)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(palette.secondaryText)
                }
            }
        }
    }

    /// Backward-compatible thin banner (rack wall etc.)
    struct Banner: View {
        let image: DecantImage
        @Environment(\.themePalette) private var palette

        var body: some View {
            HeroBanner(
                image: image,
                eyebrow: "Decantry",
                title: " ",
                subtitle: " "
            )
            .frame(height: 140)
            .allowsHitTesting(false)
            .mask(
                LinearGradient(colors: [.black, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            )
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.brass.opacity(0.35)).frame(height: 1)
            }
            .frame(height: 140)
            .clipped()
        }
    }

    struct MaturityChip: View {
        let stage: MaturityStage
        var body: some View {
            Text(stage.title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundStyle(ThemePalette.decantry.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DecantTokens.stageColor(stage).opacity(0.85), in: Capsule())
        }
    }
}

struct DecantPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Soft atmospheric wash behind cellar screens.
struct DecantAtmosphere: View {
    var body: some View {
        ZStack {
            ThemePalette.decantry.background
            RadialGradient(
                colors: [
                    Color(hex: 0x6E1E2C).opacity(0.22),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            RadialGradient(
                colors: [
                    Color(hex: 0x8A6A3E).opacity(0.12),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}
