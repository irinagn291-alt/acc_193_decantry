import SwiftUI

struct DecantSplashGate: View {
    @Environment(\.themePalette) private var palette
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DecantAtmosphere()
            // brass vignette seal
            Circle()
                .strokeBorder(palette.brass.opacity(0.18), lineWidth: 1)
                .frame(width: 280, height: 280)
                .offset(x: 80, y: -120)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 18) {
                Text("DECANTRY")
                    .font(.system(size: 36, weight: .semibold, design: .serif))
                    .tracking(6)
                    .foregroundStyle(palette.text)
                HStack(spacing: 8) {
                    Rectangle().fill(palette.brass).frame(width: 48, height: 2)
                    Text("CELLAR DESK")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .tracking(2.4)
                        .foregroundStyle(palette.brass)
                }
                if let error = environment.bootstrapError {
                    Text(error)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(palette.brass)
                } else {
                    HStack(spacing: 10) {
                        ProgressView().tint(palette.brass)
                        Text("Opening the cellar book…")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
            .padding(32)
        }
    }
}
