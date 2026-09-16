import SwiftUI

/// 连接列表页（装饰层）：自绘悬浮玻璃 tab + 自定义 + 弹层 + 玻璃卡片（自带左滑删除）。
/// 装饰层与底层完全隔离；进会话页后由远程页面接管。
struct RootView: View {
    @EnvironmentObject private var store: ConnectionStore
    @AppStorage(DecorTheme.key) private var decorRaw = DecorTheme.light.rawValue
    @Binding var tab: MainTab
    @Binding var inSession: Bool
    @State private var path: [ConnectionStore.Meta] = []
    @State private var pendingDelete: ConnectionStore.Meta?
    @State private var renameTarget: ConnectionStore.Meta?
    @State private var renameText = ""
    @State private var showScanner = false
    @State private var showManual = false
    @State private var showPlusMenu = false
    @State private var invalidAlert = ""

    private var theme: DecorTheme {
        DecorTheme(rawValue: decorRaw) ?? .light
    }

    private var shade: DecorShade {
        GlassStyle.shade(theme)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // 装饰层实底（隔离底层）+ 光斑（给玻璃透内容）
                GlassStyle.canvas(theme).ignoresSafeArea()
                GlowBackground(shade: shade).ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    if store.connections.isEmpty {
                        emptyState
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 11) {
                                ForEach(store.connections) { meta in
                                    SwipeToDeleteCard(shade: shade,
                                                      onRename: { renameTarget = meta; renameText = meta.name },
                                                      onDelete: { pendingDelete = meta }) {
                                        card(meta)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)   // 自绘标题区，不用系统导航
            .navigationDestination(for: ConnectionStore.Meta.self) { meta in
                if let s = store.urlString(for: meta) {
                    // push 进远程：通知外壳隐藏悬浮 tab，pop 回来时恢复
                    SessionView(meta: meta, urlString: s)
                        .onAppear { inSession = true }
                        .onDisappear { inSession = false }
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
        .alert("无法添加", isPresented: Binding(get: { !invalidAlert.isEmpty },
                                              set: { if !$0 { invalidAlert = "" } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(invalidAlert)
        }
        .alert("重命名连接", isPresented: Binding(get: { renameTarget != nil },
                                             set: { if !$0 { renameTarget = nil } })) {
            TextField("连接名称", text: $renameText)
            Button("保存") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let m = renameTarget, !name.isEmpty { store.rename(m, to: name) }
                renameTarget = nil
            }
            Button("取消", role: .cancel) { renameTarget = nil }
        } message: {
            Text("仅改显示名，不影响远程连接本身。")
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
        .overlay {
            if showPlusMenu { plusMenuOverlay }
        }
    }

    // MARK: - 自绘标题区 + 右上 + 钮

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ZCode")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(GlassStyle.text(shade))
                Text("远程连接 · \(store.connections.count) 台设备")
                    .font(.system(size: 12.5))
                    .foregroundStyle(GlassStyle.secondary(shade))
            }
            Spacer()
            plusButton
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var plusButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                showPlusMenu.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GlassStyle.text(shade))
                .rotationEffect(.degrees(showPlusMenu ? 45 : 0))
                .frame(width: 40, height: 40)
                .background(
                    ZStack {
                        GlassStyle.glassHighlight(shade)
                        GlassStyle.glassFillColor(shade)
                    }
                    .clipShape(Circle())
                )
                .overlay(Circle().strokeBorder(GlassStyle.stroke(shade), lineWidth: 1))
                .shadow(color: GlassStyle.floatShadow(shade), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    /// 自绘玻璃弹层菜单（替代系统 Menu，材质跟装饰层 shade）
    private var plusMenuOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { showPlusMenu = false } }

            VStack(alignment: .trailing, spacing: 0) {
                // 小箭头
                GlassArrow(shade: shade)
                    .padding(.trailing, 26)
                GlassMenuCard(shade: shade) {
                    menuRow(icon: "qrcode.viewfinder", tint: GlassStyle.accent, text: "扫码连接") {
                        showPlusMenu = false
                        showScanner = true
                    }
                    Divider().overlay(GlassStyle.stroke(shade))
                    menuRow(icon: "doc.on.clipboard", tint: .blue, text: "粘贴链接") {
                        showPlusMenu = false
                        showManual = true
                    }
                }
                .frame(width: 210)
                .padding(.trailing, 16)
            }
            .padding(.top, 96)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
        }
    }

    private func menuRow(icon: String, tint: Color, text: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(GlassStyle.text(shade))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 玻璃卡片

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
            .background(
                ZStack {
                    GlassStyle.glassHighlight(shade)
                    GlassStyle.glassFillColor(shade)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(GlassStyle.stroke(shade), lineWidth: 1))
            .shadow(color: GlassStyle.floatShadow(shade), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
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
        .padding(.top, 110)
    }

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

// MARK: - 左滑操作卡片（ScrollView 内自定义实现）：重命名 + 删除，且滑动后吞掉点击

struct SwipeToDeleteCard<Content: View>: View {
    let shade: DecorShade
    let onRename: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offsetX: CGFloat = 0
    @GestureState private var dragState: CGFloat = 0
    /// 本次触摸发生过横向滑动 → 吞掉随之而来的点击（防止滑一下直接进远程）
    @State private var consumedTap = false

    private let actionWidth: CGFloat = 150   // 重命名 + 删除 两颗按钮总宽

    private var currentOffset: CGFloat {
        min(0, max(-actionWidth - 24, offsetX + dragState))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offsetX = 0 }
                    onRename()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("重命名").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 78)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offsetX = 0 }
                    onDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("删除").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 78)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .opacity(currentOffset < -12 ? 1 : 0)
            .padding(.trailing, 6)

            content
                .offset(x: currentOffset)
                // 滑动发生后的短暂窗口内禁点：吞掉随滑动而来的 tap（防误进远程）
                .allowsHitTesting(!consumedTap)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .updating($dragState) { g, state, _ in
                            // 只响应横向主导的拖动，避免吃掉纵向滚动
                            if abs(g.translation.width) > abs(g.translation.height) {
                                state = g.translation.width
                                if abs(g.translation.width) > 12 { consumedTap = true }
                            }
                        }
                        .onEnded { _ in
                            if consumedTap {
                                // 滑动结束：开档或归位，并在短暂窗口内拦截点击
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offsetX = currentOffset < -actionWidth / 2 ? -actionWidth : 0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    consumedTap = false
                                }
                            }
                        }
                )
                .onTapGesture { }
                .allowsHitTesting(true)
        }
        .onChange(of: dragState) { _, new in
            _ = new
        }
    }
}

// MARK: - 悬浮玻璃胶囊 tab（连接/设置），自绘

enum MainTab: String { case connections, settings }

struct FloatingGlassTab: View {
    let shade: DecorShade
    let activeTab: MainTab
    var onSelect: ((MainTab) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            tabItem(.connections, icon: "bolt.fill", label: "连接")
            tabItem(.settings, icon: "gearshape", label: "设置")
        }
        .padding(5)
        .background(
            ZStack {
                GlassStyle.glassHighlight(shade)
                GlassStyle.glassFillColor(shade)
            }
            .clipShape(Capsule())
        )
        .overlay(Capsule().strokeBorder(GlassStyle.stroke(shade), lineWidth: 1))
        .shadow(color: GlassStyle.floatShadow(shade), radius: 16, y: 6)
        .padding(.bottom, 18)
    }

    private func tabItem(_ tab: MainTab, icon: String, label: String) -> some View {
        let active = activeTab == tab
        return Button {
            onSelect?(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19, weight: .semibold))
                Text(label).font(.system(size: 10.5, weight: .bold))
            }
            .foregroundStyle(active ? GlassStyle.accent : GlassStyle.secondary(shade))
            .frame(width: 86, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(active ? GlassStyle.accentSoft : Color.clear)
            )
            .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(active ? GlassStyle.accent.opacity(0.4) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// 菜单小箭头
struct GlassArrow: View {
    let shade: DecorShade
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(GlassStyle.glassFillColor(shade))
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(45))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(GlassStyle.stroke(shade), lineWidth: 1))
            .simultaneousGesture(TapGesture())
    }
}

/// 玻璃菜单卡片
struct GlassMenuCard<Content: View>: View {
    let shade: DecorShade
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                ZStack {
                    GlassStyle.glassHighlight(shade)
                    GlassStyle.glassFillColor(shade)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(GlassStyle.stroke(shade), lineWidth: 1))
            .shadow(color: GlassStyle.floatShadow(shade), radius: 20, y: 8)
    }
}
