import SwiftUI

@main
struct ZCodeShellApp: App {
    @StateObject private var store = ConnectionStore.shared

    var body: some Scene {
        WindowGroup {
            MainShellView()
                .environmentObject(store)
        }
    }
}

/// 壳主结构：列表/设置两页 + 悬浮玻璃 tab 切换；进会话页时 tab 隐藏。
/// 装饰层自带整页实底（canvasColor），与底层窗口颜色完全隔离。
struct MainShellView: View {
    @EnvironmentObject private var store: ConnectionStore
    @AppStorage(DecorTheme.key) private var decorRaw = DecorTheme.light.rawValue
    @State private var tab: MainTab = .connections
    @State private var inSession = false

    private var theme: DecorTheme {
        DecorTheme(rawValue: decorRaw) ?? .light
    }

    private var shade: DecorShade {
        GlassStyle.shade(theme)
    }

    var body: some View {
        ZStack {
            // 装饰层实底：全屏铺，底层窗口颜色变化透不上来
            GlassStyle.canvas(theme).ignoresSafeArea()
            switch tab {
            case .connections:
                NavigationStack {
                    RootView(tab: $tab, inSession: $inSession)
                }
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .overlay(alignment: .bottom) {
            // 进远程会话页（push 后）隐藏悬浮 tab：底层完全交给远程页面
            if !inSession {
                FloatingGlassTab(shade: shade, activeTab: tab) { newTab in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        tab = newTab
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: inSession)
    }
}
