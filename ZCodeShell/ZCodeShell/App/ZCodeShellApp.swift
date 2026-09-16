import SwiftUI

@main
struct ZCodeShellApp: App {
    @StateObject private var store = ConnectionStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
