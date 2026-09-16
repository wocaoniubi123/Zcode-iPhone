import SwiftUI
import WebKit

/// WKWebView 封装：持有 controller 以支持程序化刷新，外观跟随全局设置。
struct RemoteWebView: UIViewRepresentable {
    let url: URL
    /// 外部递增即触发 reload（打开页面、回前台、手动刷新共用）
    let reloadToken: Int
    let appearance: AppearanceMode

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        web.overrideUserInterfaceStyle = appearance.uiStyle
        context.coordinator.web = web
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        web.overrideUserInterfaceStyle = appearance.uiStyle
        if reloadToken != context.coordinator.lastToken {
            context.coordinator.lastToken = reloadToken
            // 首次 token 变化发生在 makeUIView 之后的首次 update，此时页面刚 load，重复 reload 无害但浪费；
            // 用 web.url 是否已指向目标来过滤首次
            if web.url != nil {
                web.reload()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(lastToken: reloadToken) }

    final class Coordinator {
        var web: WKWebView?
        var lastToken: Int
        init(lastToken: Int) { self.lastToken = lastToken }
    }
}

/// 会话页 = WKWebView 加载官方 remote/v4 页面。
/// 打开时与回前台时自动刷新，工具栏另有手动刷新。
struct SessionView: View {
    let meta: ConnectionStore.Meta
    let urlString: String

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var reloadToken = 0

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                RemoteWebView(url: url, reloadToken: reloadToken, appearance: appearance)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Text("链接无效，请删除后重新添加").foregroundStyle(.red)
            }
        }
        .navigationTitle(meta.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reloadToken += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }.accessibilityLabel("刷新")
            }
        }
        .onAppear { reloadToken += 1 }          // 打开即刷新
        .onChange(of: scenePhase) { phase in
            if phase == .active { reloadToken += 1 }  // 回前台刷新出最新对话
        }
    }
}
