import SwiftUI

/// 连接列表页（装饰层）：玻璃卡片 + 右上 + 菜单 + 底部悬浮 tab。
/// 底层颜色规则不变：点卡片进会话页后一切由远程页面接管。
struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage(DecorTheme.key) private var decorRaw = DecorTheme.system.rawValue
    @State private var path: [ConnectionStore.Meta] = []
    @State private var didAutoOpen = false
    @State private var pendingDelete: ConnectionStore.Meta?

    private var shade: DecorShade {
        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .system, scheme: systemScheme)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // 底层：装饰光斑（给玻璃透内容）
                GlowBackground(shade: shade).ignoresSafeArea()

                // List 才有原生 swipeActions（左滑删除）；行背景透明化以露出玻璃材质
                List {
                    if store.connections.isEmpty {
                        emptyState
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(store.connections) { meta in
                            card(meta)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("ZCode")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    plusMenu
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
            path.append(last)
        }
        .confirmationDialog("删除连接「\(pendingDelete?.name ?? "")」？",
                            isPresented: Binding(get: { pendingDelete != nil },
                                                 set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let m = pendingDelete { store.delete(m) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("该连接的凭证将被移除，无法恢复。")
        }
    }

    @State private var showScanner = false
    @State private var showManual = false

    /// 右上 + 玻璃钮 → 菜单（扫码/粘贴）
    private var plusMenu: some View {
        Menu {
            Button { showScanner = true } label: {
                Label("扫码连接", systemImage: "qrcode.viewfinder")
            }
            Button { showManual = true } label: {
                Label("粘贴链接", systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GlassStyle.text(shade))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(GlassStyle.stroke(shade), lineWidth: 1))
        }
        .tint(GlassStyle.accent)
    }

    /// 连接玻璃卡片
    private func card(_ meta: ConnectionStore.Meta) -> some View {
        Button { path.append(meta) } label: {
            HStack(spacing: 12) {
                Text(String(meta.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(colors: GlassStyle.avatarGradient(meta.name),
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(meta.name)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(GlassStyle.text(shade))
                        .lineLimit(1)
                    Text("zcode.z.ai · \(timeLabel(meta.lastUsed))")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassStyle.secondary(shade))
                }
                Spacer(minLength: 0)
                if meta.id == store.lastConnectionID {
                    Text("上次")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(GlassStyle.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(GlassStyle.accentSoft))
                        .overlay(Capsule().strokeBorder(GlassStyle.accent.opacity(0.3), lineWidth: 1))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GlassStyle.secondary(shade).opacity(0.6))
            }
            .padding(14)
            .background(GlassStyle.material(shade), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .strokeBorder(GlassStyle.stroke(shade), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                pendingDelete = meta
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(GlassStyle.secondary(shade))
            Text("还没有连接")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GlassStyle.text(shade))
            Text("点右上角 + 扫码，或粘贴 PC 端 ZCode 给出的远程链接")
                .font(.system(size: 13))
                .foregroundStyle(GlassStyle.secondary(shade))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
        .padding(.bottom, 110)
    }

    private func handle(_ raw: String) {
        guard let conn = ConnectionParser.parse(raw) else {
            invalidAlert = "不是有效的 ZCode 官方链接\n(https://…zcode.z.ai/remote/…)"
            return
        }
        path.append(store.upsert(conn))
    }

    @State private var invalidAlert = ""

    private func timeLabel(_ d: Date) -> String {
        d == .distantPast ? "未使用" : d.formatted(date: .abbreviated, time: .shortened)
    }
}

/// 底层装饰光斑
struct GlowBackground: View {
    let shade: DecorShade
    var body: some View {
        ZStack {
            let colors = GlassStyle.glow(shade)
            Circle().fill(colors[0]).frame(width: 240, height: 240)
                .blur(radius: 60).offset(x: 110, y: -190)
            Circle().fill(colors[1]).frame(width: 200, height: 200)
                .blur(radius: 60).offset(x: -120, y: 260)
        }
        .allowsHitTesting(false)
    }
}
