import SwiftUI

/// 首页：上次连接置顶大按钮 + 历史连接列表 + 扫码/手动添加。
/// 启动时若有"上次连接"，自动打开会话页（失败会停在会话页显示错误）。
struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @State private var path: [ZCodeConnection] = []
    @State private var showScanner = false
    @State private var showManual = false
    @State private var didAutoOpen = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("全部连接") {
                    if store.connections.isEmpty {
                        Text("还没有连接。点右上角扫码添加。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.connections) { conn in
                        Button { path.append(conn) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conn.name).foregroundStyle(.primary)
                                    Text(conn.displayAddress + (conn.useTLS ? "  🔒" : ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(conn.id == store.lastConnectionID ? "上次" : "")
                                    .font(.caption2).foregroundStyle(.tint)
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(conn)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("ZCode")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showManual = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showScanner = true } label: { Image(systemName: "qrcode.viewfinder") }
                }
            }
            .navigationDestination(for: ZCodeConnection.self) { conn in
                SessionView(model: SessionModel(connection: conn) {
                    store.token(for: conn.id)
                })
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { raw in
                showScanner = false
                handleScan(raw)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showManual) {
            ManualAddView { host, port, tls, token in
                showManual = false
                let conn = store.upsert(host: host, port: port, useTLS: tls, token: token)
                path.append(conn)
            }
        }
        .onAppear {
            guard !didAutoOpen, let last = store.lastConnection else { return }
            didAutoOpen = true
            path.append(last)   // 打开 app 直接进上次连接
        }
    }

    private func handleScan(_ raw: String) {
        guard let (conn, token) = ConnectionParser.parse(raw) else {
            showManual = true  // 扫到未知内容 → 落到手动输入
            return
        }
        let saved = store.upsert(host: conn.host, port: conn.port, useTLS: conn.useTLS, token: token)
        path.append(saved)
    }
}
