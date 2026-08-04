import SwiftUI

@main
struct DecantryApp: App {
    @StateObject private var cellarEnvironment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(cellarEnvironment)
                .environment(\.themePalette, ThemePalette.decantry)
        }
    }
}
