import SwiftUI

enum DecantEmpty {
    struct Panel: SwiftUI.View {
        let image: DecantImage
        let title: String
        let message: String
        var systemImage: String? = nil
        var actionTitle: String?
        var action: (() -> Void)?

        @Environment(\.themePalette) private var palette

        var body: some SwiftUI.View {
            VStack(spacing: DecantTokens.panelInset) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(palette.brass.opacity(0.75))
                        .frame(height: 56)
                } else {
                    image.image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 72)
                }
                Text(title)
                    .font(DecantTokens.titleFont())
                    .foregroundStyle(palette.text)
                Text(message)
                    .font(DecantTokens.bodyFont())
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                if let actionTitle, let action {
                    DecantChrome.primaryButton(actionTitle, action: action)
                }
            }
            .padding(DecantTokens.panelInset)
        }
    }
}
