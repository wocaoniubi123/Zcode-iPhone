import SwiftUI

@main
struct ZCodeShellApp: App {
    @StateObject private var store = ConnectionStore.shared
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
