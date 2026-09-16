import SwiftUI
import WebKit
import UIKit
import Photos

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

        // 长按图片 → 自接管菜单（保存到相册/复制图片），替代 WKWebView 内置英文菜单，
        // 并提供"已保存"反馈（内置菜单存图无任何提示）
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.longPress(_:)))
        longPress.minimumPressDuration = 0.35
        longPress.delegate = context.coordinator
        web.addGestureRecognizer(longPress)

        // 键盘首弹校准：第一次键盘弹出时强推一次 resize，让官方页面的键盘适配"热身"，
        // 否则首次输入框会被键盘挡住（第二次起 WebView 视口已初始化，系统自己正常）
        context.coordinator.keyboardObserver = NotificationCenter.default
            .addObserver(forName: UIResponder.keyboardWillShowNotification,
                         object: nil, queue: .main) { [weak coordinator = context.coordinator] note in
                guard let coordinator, let web = coordinator.web else { return }
                coordinator.keyboardCalibrationCount += 1
                // 只在首一两次介入（之后系统链路已正常，不再干预）
                guard coordinator.keyboardCalibrationCount <= 2 else { return }
                // 强制官方页面重算视口（visualViewport 变化），触发它自己的键盘上移逻辑
                web.evaluateJavaScript("""
                    (function(){
                      window.dispatchEvent(new Event('resize'));
                      if (window.visualViewport) window.visualViewport.dispatchEvent(new Event('resize'));
                    })()
                    """, completionHandler: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak web] in
                    web?.evaluateJavaScript("window.dispatchEvent(new Event('resize'))", completionHandler: nil)
                }
            }

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
        if let obs = coordinator.keyboardObserver { NotificationCenter.default.removeObserver(obs) }
        coordinator.web?.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate, WKUIDelegate {
        var web: WKWebView?
        var lastToken: Int
        var onExit: (() -> Void)?
        var onThemeChange: ((Bool) -> Void)?
        var keyboardObserver: NSObjectProtocol?
        var keyboardCalibrationCount = 0
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

        // MARK: - 长按图片接管

        @objc func longPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, let web else { return }
            let point = g.location(in: web)
            // hit-test 取长按位置的 <img> 的 src（viewport 坐标）
            let pick = """
            (function(){
              var el = document.elementFromPoint(\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)));
              if (!el || el.tagName !== 'IMG') return null;
              var r = el.getBoundingClientRect();
              var src = el.currentSrc || el.src;
              return src ? JSON.stringify({src: src, w: r.width, h: r.height}) : null;
            })()
            """
            web.evaluateJavaScript(pick) { [weak self] result, _ in
                guard let json = result as? String,
                      let data = json.data(using: .utf8),
                      let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let src = info["src"] as? String, !src.isEmpty else { return }
                self?.showImageMenu(src: src, in: web, at: point)
            }
        }

        /// 自接管图片菜单（中文，只留保存），替代系统英文菜单
        private func showImageMenu(src: String, in web: WKWebView, at point: CGPoint) {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "保存到相册", style: .default) { [weak self] _ in
                self?.saveImage(from: src, in: web)
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            // iPad 必须给 sourceView，否则弹不出
            if let root = rootViewController() {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    alert.popoverPresentationController?.sourceView = web
                    alert.popoverPresentationController?.sourceRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
                }
                root.present(alert, animated: true)
            }
        }

        /// 取图片数据：先试页面内 fetch（带页面会话上下文/cookie），dataURL 直接解
        private func fetchImageData(src: String, in web: WKWebView, done: @escaping (Data?) -> Void) {
            if src.hasPrefix("data:") {
                if let url = URL(string: src), let d = try? Data(contentsOf: url) { done(d) } else { done(nil) }
                return
            }
            let js = """
            (function(){
              return fetch(\(jsonEscape(src)), {credentials:'include'})
                .then(r => r.ok ? r.blob() : Promise.reject(0))
                .then(b => new Promise(res => {
                  var fr = new FileReader();
                  fr.onload = () => res(fr.result);
                  fr.readAsDataURL(b);
                }))
                .catch(() => null);
            })()
            """
            web.evaluateJavaScript(js) { result, _ in
                guard let s = result as? String, s.hasPrefix("data:"),
                      let url = URL(string: s), let d = try? Data(contentsOf: url) else { done(nil); return }
                done(d)
            }
        }

        private func saveImage(from src: String, in web: WKWebView) {
            fetchImageData(src: src, in: web) { data in
                guard let data else {
                    self.toast("获取图片失败")
                    return
                }
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    guard status == .authorized || status == .limited else {
                        DispatchQueue.main.async { self.toast("没有相册权限") }
                        return
                    }
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: UIImage(data: data) ?? UIImage())
                    }) { ok, _ in
                        DispatchQueue.main.async {
                            self.toast(ok ? "已保存到相册" : "保存失败")
                        }
                    }
                }
            }
        }

        // MARK: - Toast

        private func toast(_ text: String) {
            guard let root = rootViewController() else { return }
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = UIColor(white: 0, alpha: 0.75)
            label.layer.cornerRadius = 18
            label.clipsToBounds = true
            let w = min(max(label.intrinsicContentSize.width + 44, 120), 300)
            label.frame = CGRect(x: 0, y: 0, width: w, height: 44)
            label.translatesAutoresizingMaskIntoConstraints = true
            root.view.addSubview(label)
            label.center = CGPoint(x: root.view.bounds.midX, y: root.view.bounds.height - 120)
            label.alpha = 0
            UIView.animate(withDuration: 0.2) { label.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                UIView.animate(withDuration: 0.3, animations: { label.alpha = 0 }) { _ in
                    label.removeFromSuperview()
                }
            }
        }

        private func rootViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap { $0.windows }.first(where: \.isKeyWindow)?.rootViewController
        }

        private func jsonEscape(_ s: String) -> String {
            let data = try? JSONSerialization.data(withJSONObject: [s])
            return String(data: data ?? Data("null".utf8), encoding: .utf8) ?? "null"
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // 长按手势与 WKWebView 内置长按（弹英文菜单）互斥：
            // 我们的 minimumPressDuration(0.35s) 短于系统(~0.5s) 必先识别；互斥保证独占
            if gestureRecognizer is UILongPressGestureRecognizer,
               other is UILongPressGestureRecognizer {
                return false
            }
            return true  // 左滑边缘手势不阻止官方页面自身的边缘交互
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
            // 三态直切：远程主题 → 装饰主题，窗口配色无中间态，状态栏不闪
            WindowHost.shared.apply(.decor(DecorTheme(rawValue: UserDefaults.standard.string(forKey: DecorTheme.key) ?? "") ?? .light))
        }
    }

    /// 底层窗口色跟远程页面真实主题（探针上报，固化为底层行为，无开关）。
    /// 装饰层主题与此无关。窗口实底色同步铺（SwiftUI 之下，永不露缝）。
    private func applyWindowStyle(_ dark: Bool) {
        Task { @MainActor in
            WindowHost.shared.apply(.remote(dark: dark))
        }
    }
}
