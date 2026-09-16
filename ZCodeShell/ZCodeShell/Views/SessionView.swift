import SwiftUI
import WebKit
import UIKit

/// WKWebView 封装：
/// - 打开/回前台/手动 token 递增 → reload
/// - 左滑：官方页面有历史(goBack)先在页面内回退；退无可退 → 退出到连接列表
/// - 注入 JS 探测官方页面真实主题（深/浅）→ 回调给壳设状态栏文字颜色
struct RemoteWebView: UIViewRepresentable {
    let url: URL
    let reloadToken: Int
    let onExit: () -> Void
    let onThemeChange: (Bool) -> Void   // true = 页面深色

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true

        // 主题探针：官方页面把主题写在 <html data-zcode-bootstrap-theme="dark|light">，
        // 另有 --zcode-bootstrap-bg 变量兜底。变化时经 messageHandlers.theme 上报。
        let probe = WKUserScript(source: Self.themeProbeJS,
                                 injectionTime: .atDocumentStart,
                                 forMainFrameOnly: true)
        cfg.userContentController.addUserScript(probe)
        cfg.userContentController.add(context.coordinator, name: "theme")

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = false   // 左滑逻辑统一走自定义手势
        context.coordinator.web = web
        context.coordinator.onExit = onExit
        context.coordinator.onThemeChange = onThemeChange

        let edge = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.edgePan(_:)))
        edge.edges = .left
        edge.delegate = context.coordinator
        web.addGestureRecognizer(edge)

        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.onExit = onExit
        context.coordinator.onThemeChange = onThemeChange
        if reloadToken != context.coordinator.lastToken {
            context.coordinator.lastToken = reloadToken
            if web.url != nil {   // 过滤 makeUIView 后首轮 update 的重复 reload
                web.reload()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(lastToken: reloadToken) }

    static func dismantleCoordinator(_ coordinator: Coordinator) {
        coordinator.web?.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        var web: WKWebView?
        var lastToken: Int
        var onExit: (() -> Void)?
        var onThemeChange: ((Bool) -> Void)?
        init(lastToken: Int) { self.lastToken = lastToken }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "theme",
                  let body = message.body as? [String: Any],
                  let dark = body["dark"] as? Bool else { return }
            DispatchQueue.main.async { self.onThemeChange?(dark) }
        }

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

    /// 先读官方主题属性；缺失时按 body 实际背景色亮度判；再兜底系统深色。
    static let themeProbeJS = """
    (function(){
      var lum = function(c){
        var m = /rgba?\\(([^)]+)\\)/.exec(c);
        if (!m) return null;
        var p = m[1].split(',').map(parseFloat);
        if (p.length < 3) return null;
        return (0.299*p[0] + 0.587*p[1] + 0.114*p[2]) / 255;
      };
      var send = function(){
        var root = document.documentElement;
        var t = root.getAttribute('data-zcode-bootstrap-theme');
        var dark;
        if (t === 'dark' || t === 'zai-dark') dark = true;
        else if (t === 'light' || t === 'zai-light') dark = false;
        else {
          var bg = getComputedStyle(document.body).backgroundColor;
          var l = bg ? lum(bg) : null;
          dark = (l !== null) ? (l < 0.55)
               : (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
        }
        try { window.webkit.messageHandlers.theme.postMessage({dark: dark}); } catch(e) {}
      };
      send();
      document.addEventListener('DOMContentLoaded', send);
      window.addEventListener('load', send);
      new MutationObserver(send).observe(document.documentElement,
        {attributes:true, attributeFilter:['data-zcode-bootstrap-theme','style','class']});
    })();
    """
}

/// 会话页：全屏 WebView（顶底直达物理屏幕边，Safari 同款），
/// 无壳导航栏。状态栏文字颜色跟随官方页面真实主题。
struct SessionView: View {
    let meta: ConnectionStore.Meta
    let urlString: String

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var reloadToken = 0
    @State private var pageIsDark = true   // 官方页面 meta color-scheme: dark，深色为缺省猜测
    @State private var hasAppeared = false // 冷启动首次进入不刷新；后台回来才刷

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                RemoteWebView(url: url, reloadToken: reloadToken,
                              onExit: { dismiss() },
                              onThemeChange: { pageIsDark = $0 })
                    // Safari 同款：顶底全铺满，页面画布直达物理屏幕边；
                    // 状态栏文字叠在页面底色上，官方页面自己处理顶部安全区避让
                    .ignoresSafeArea()
            } else {
                Text("链接无效，请删除后重新添加").foregroundStyle(.red)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 首次进入：页面本来就是新加载的，不重复刷新
            hasAppeared = true
            applyWindowStyle(pageIsDark)
        }
        .onChange(of: pageIsDark) { _ in applyWindowStyle(pageIsDark) }
        .onChange(of: scenePhase) { phase in
            // 从后台回前台（会话页还在栈里）才刷新拉最新对话
            if phase == .active, hasAppeared {
                reloadToken += 1
            }
        }
        .onDisappear {
            setWindowOverride(.unspecified)       // 退出会话页，底层颜色交还系统
        }
    }

    /// 底层窗口色跟远程页面真实主题（探针上报，固化为底层行为，无开关）。
    /// 装饰层主题与此无关。
    private func applyWindowStyle(_ dark: Bool) {
        setWindowOverride(dark ? .dark : .light)
    }

    private func setWindowOverride(_ style: UIUserInterfaceStyle) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes where scene.activationState == .foregroundActive {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
