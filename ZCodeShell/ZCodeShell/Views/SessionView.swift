import SwiftUI
import WebKit
import UIKit

/// WKWebView 封装：
/// - 打开/回前台/手动 token 递增 → reload
/// - 左滑：官方页面有历史(goBack)先在页面内回退；退无可退 → 退出到连接列表
/// - 外观跟随全局设置
struct RemoteWebView: UIViewRepresentable {
    let url: URL
    /// 外部递增即触发 reload
    let reloadToken: Int
    let appearance: AppearanceMode
    /// 页面内历史退无可退时的左滑退出回调
    let onExit: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = false   // 左滑逻辑统一走自定义手势
        web.overrideUserInterfaceStyle = appearance.uiStyle
        context.coordinator.web = web
        context.coordinator.onExit = onExit

        let edge = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.edgePan(_:)))
        edge.edges = .left
        edge.delegate = context.coordinator
        web.addGestureRecognizer(edge)

        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        web.overrideUserInterfaceStyle = appearance.uiStyle
        context.coordinator.onExit = onExit
        if reloadToken != context.coordinator.lastToken {
            context.coordinator.lastToken = reloadToken
            if web.url != nil {   // 过滤 makeUIView 后首轮 update 的重复 reload
                web.reload()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(lastToken: reloadToken) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var web: WKWebView?
        var lastToken: Int
        var onExit: (() -> Void)?
        init(lastToken: Int) { self.lastToken = lastToken }

        @objc func edgePan(_ g: UIScreenEdgePanGestureRecognizer) {
            guard g.state == .ended else { return }
            if let web, web.canGoBack {
                web.goBack()      // 对话框 → 对话列表（官方页面内回退）
            } else {
                onExit?()         // 页面内已到顶 → 回连接列表
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true  // 不阻止官方页面自身的边缘交互
        }
    }
}

/// 会话页：全屏 WebView（顶部止于状态栏下，底部铺到 home indicator），
/// 无壳导航栏。打开时与回前台时自动刷新出最新对话。
struct SessionView: View {
    let meta: ConnectionStore.Meta
    let urlString: String

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var reloadToken = 0

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                RemoteWebView(url: url, reloadToken: reloadToken,
                              appearance: appearance, onExit: { dismiss() })
                    // Safari 同款：顶底全铺满，页面画布直达物理屏幕边，
                    // 状态栏文字叠在页面底色上；官方页面自己处理顶部安全区避让
                    .ignoresSafeArea()
            } else {
                Text("链接无效，请删除后重新添加").foregroundStyle(.red)
            }
        }
        .toolbar(.hidden, for: .navigationBar)   // 去掉 "返回 ZCode / 计算机名 / 刷新" 整条
        .statusBarStyle(appearance.statusBarStyle) // 状态栏文字颜色跟随外观
        .onAppear { reloadToken += 1 }
        .onChange(of: scenePhase) { phase in
            if phase == .active { reloadToken += 1 }
        }
    }
}

/// 状态栏文字颜色：深色页面→白字，浅色→黑字，跟随系统→交给系统
extension AppearanceMode {
    var statusBarStyle: UIStatusBarStyle {
        switch self {
        case .system: return .default
        case .light: return .darkContent
        case .dark: return .lightContent
        }
    }
}

/// SwiftUI 修饰器：托管状态栏样式。
/// 原理：插一个隐藏的 UIViewController 作为状态栏样式决定者（childForStatusBarStyle 链），
/// scene 架构下 UIWindow 硬 override 不可靠，这是可靠做法。
struct StatusBarStyleModifier: ViewModifier {
    let style: UIStatusBarStyle
    @State private var host = StatusBarHostVC()

    func body(content: Content) -> some View {
        content.background(
            StatusBarHost(vc: host)   // 常驻视图层级，VC 的 preferredStatusBarStyle 生效
                .frame(width: 0, height: 0)
        )
        .onAppear { host.style = style }
        .onChange(of: style) { _ in
            host.style = style
            host.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

/// 状态栏样式决定者：SwiftUI 内嵌的 UIViewController。
final class StatusBarHostVC: UIViewController {
    var style: UIStatusBarStyle = .default

    override var preferredStatusBarStyle: UIStatusBarStyle { style }
}

/// 把 UIViewController 挂进 SwiftUI 层级的 representable。
struct StatusBarHost: UIViewControllerRepresentable {
    let vc: StatusBarHostVC

    func makeUIViewController(context: Context) -> StatusBarHostVC { vc }
    func updateUIViewController(_ vc: StatusBarHostVC, context: Context) {}
}

extension View {
    func statusBarStyle(_ style: UIStatusBarStyle) -> some View {
        modifier(StatusBarStyleModifier(style: style))
    }
}
