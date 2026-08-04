import SwiftUI

struct RootView: View {
    private static let gateHoldSeconds: Double = 0.6

    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage(DecantDefaults.onboardingCompleted) private var onboardingCompleted = false
    @State private var stage: Stage = .gate

    private enum Stage {
        case gate
        case onboarding
        case cellar
    }

    var body: some View {
        Group {
            switch stage {
            case .gate:
                DecantSplashGate()
            case .onboarding:
                DecantOnboardingView(onFinished: completeOnboarding)
            case .cellar:
                RackWallHubView()
            }
        }
        .environment(\.themePalette, ThemePalette.decantry)
        .preferredColorScheme(.dark)
        .task {
            await environment.bootstrap()
            try? await Task.sleep(for: .seconds(Self.gateHoldSeconds))
            guard environment.bootstrapError == nil else { return }
            // Seeder (Simulator) may mark onboarding complete via UserDefaults.
            onboardingCompleted = UserDefaults.standard.bool(forKey: DecantDefaults.onboardingCompleted)
            stage = onboardingCompleted ? .cellar : .onboarding
        }
    }

    private func completeOnboarding() {
        onboardingCompleted = true
        environment.markOnboardingCompleted()
        stage = .cellar
    }
}
