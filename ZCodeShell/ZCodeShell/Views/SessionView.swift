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
        web.uiDelegate = context.coordinator              // 保存图片等系统弹层回调
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

    final class Coordinator: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate, WKUIDelegate {
        var web: WKWebView?
        var lastToken: Int
        var onExit: (() -> Void)?
        var onThemeChange: ((Bool) -> Void)?
        init(lastToken: Int) { self.lastToken = lastToken }

        /// 系统原生"存储图像/拷贝图像"弹层（长按图片）需要 UI 上下文；
        /// 缺省实现时 WKWebView 部分路径会直接崩 → 兜底兑现请求。
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)   // 相机/麦克风授权请求直接放行（远程会话可能用得到）
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

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

    }
}
