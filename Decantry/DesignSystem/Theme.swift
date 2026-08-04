import SwiftUI

struct ThemePalette: Hashable, Sendable {
    let background: Color
    let surface: Color
    let surfaceRaised: Color
    let oak: Color
    let wine: Color
    let brass: Color
    let text: Color
    let secondaryText: Color
    let divider: Color

    static let decantry = ThemePalette(
        background: Color(hex: 0x1B1D22),
        surface: Color(hex: 0x24262C),
        surfaceRaised: Color(hex: 0x2C2F36),
        oak: Color(hex: 0x8A6A3E),
        wine: Color(hex: 0x6E1E2C),
        brass: Color(hex: 0xC9A24A),
        text: Color(hex: 0xF2EDE4),
        secondaryText: Color(hex: 0xA39E94),
        divider: Color(hex: 0x34373F)
    )
}

enum DecantTokens {
    static let cornerSmall: CGFloat = 8
    static let cornerMedium: CGFloat = 12
    static let rackCellSize: CGFloat = 44
    static let dialSide: CGFloat = 72
    static let panelInset: CGFloat = 16

    static func titleFont() -> Font {
        .system(.title2, design: .serif).weight(.semibold)
    }

    static func headlineFont() -> Font {
        .headline.weight(.semibold)
    }

    static func bodyFont() -> Font {
        .body
    }

    static func captionFont() -> Font {
        .caption.weight(.medium)
    }

    static func monoFont(_ style: Font.TextStyle = .subheadline) -> Font {
        .system(style, design: .monospaced)
    }

    static func stageColor(_ stage: MaturityStage) -> Color {
        switch stage {
        case .young: Color(hex: 0x5B7FFF)
        case .approaching: Color(hex: 0xC9A24A)
        case .ready: Color(hex: 0x4A9B6E)
        case .holding: Color(hex: 0x8A6A3E)
        case .pastPeak: Color(hex: 0x6E1E2C)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.decantry
}

extension EnvironmentValues {
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

@MainActor
final class DecantVMBox<T: ObservableObject>: ObservableObject {
    @Published var value: T?
}
