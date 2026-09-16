import SwiftUI

/// 首页：连接列表（最近在前）。右上角扫码，左上角粘贴链接。
/// 启动时自动进入最近一条连接。
struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var path: [ConnectionStore.Meta] = []
    @State private var showScanner = false
    @State private var showManual = false
    @State private var didAutoOpen = false
    @State private var invalidAlert = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("全部连接") {
                    if store.connections.isEmpty {
                        Text("还没有连接。点右上角扫码，或左上角粘贴官方链接。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.connections) { meta in
                        Button { path.append(meta) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meta.name).foregroundStyle(.primary)
                                    Text(timeLabel(meta.lastUsed))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(meta.id == store.lastConnectionID ? "上次" : "")
                                    .font(.caption2).foregroundStyle(.tint)
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(meta)
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
                    Button { showManual = true } label: { Image(systemName: "doc.on.clipboard") }
                        .accessibilityLabel("粘贴链接添加")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showScanner = true } label: { Image(systemName: "qrcode.viewfinder") }
                        .accessibilityLabel("扫码添加")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(AppearanceMode.allCases) { m in
                            Button {
                                appearanceRaw = m.rawValue
                            } label: {
                                Label(m.label, systemImage: m.icon)
                            }
                        }
                    } label: {
                        // 菜单图标跟随当前模式（AppStorage 变化驱动重建）
                        Image(systemName: (AppearanceMode(rawValue: appearanceRaw) ?? .system).icon)
                    }.accessibilityLabel("外观")
                }
            }
            .navigationDestination(for: ConnectionStore.Meta.self) { meta in
                if let s = store.urlString(for: meta) {
                    SessionView(meta: meta, urlString: s)
                } else {
                    Text("凭证丢失，请删除后重新添加").foregroundStyle(.red)
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { raw in
                showScanner = false
                handle(raw)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showManual) {
            ManualAddView { raw in
                showManual = false
                handle(raw)
            }
        }
        .onAppear {
            guard !didAutoOpen, let last = store.lastConnection else { return }
            didAutoOpen = true
            path.append(last)   // 打开 app 直接进最近连接
        }
        .alert("无法添加", isPresented: .init(
            get: { !invalidAlert.isEmpty },
            set: { if !$0 { invalidAlert = "" } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(invalidAlert)
        }
    }

    /// 扫码与粘贴共用入口：合法官方链接 → upsert → 打开；否则提示无效。
    private func handle(_ raw: String) {
        guard let conn = ConnectionParser.parse(raw) else {
            invalidAlert = "不是有效的 ZCode 官方链接\n(https://…zcode.z.ai/remote/…)"
            return
        }
        path.append(store.upsert(conn))
    }

    private func timeLabel(_ d: Date) -> String {
        d == .distantPast ? "未使用" : d.formatted(date: .abbreviated, time: .shortened)
    }
}
