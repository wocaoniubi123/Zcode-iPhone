import SwiftUI
import WebKit

/// 会话页 = WKWebView 加载官方 remote/v4 页面。官方页面自带全部交互。
struct RemoteWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}

/// 点一条连接 → 直接进 WebView。
struct SessionView: View {
    let meta: ConnectionStore.Meta
    let urlString: String

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                RemoteWebView(url: url)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Text("链接无效，请删除后重新添加").foregroundStyle(.red)
            }
        }
        .navigationTitle(meta.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
