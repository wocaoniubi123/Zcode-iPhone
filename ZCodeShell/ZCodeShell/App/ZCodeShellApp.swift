import SwiftUI

@main
struct ZCodeShellApp: App {
    @StateObject private var store = ConnectionStore.shared

    // 底层功能色：跟随系统（装饰层主题与底层隔离，见 DecorTheme）
    var body: some Scene {
        WindowGroup {
            TabView {
                RootView()
                    .tabItem { Label("连接", systemImage: "bolt.fill") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
            .tint(GlassStyle.accent)
            .environmentObject(store)
        }
    }
}
