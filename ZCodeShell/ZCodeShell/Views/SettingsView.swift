import SwiftUI

/// 设置页（装饰层）：主题三选一 / 状态栏跟随远程开关 / 清除连接（二次确认）/ 版本。
struct SettingsView: View {
    @EnvironmentObject private var store: ConnectionStore
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage(DecorTheme.key) private var decorRaw = DecorTheme.system.rawValue
    @AppStorage("zcode.statusbarFollowRemote.v1") private var statusbarFollowRemote = true
    @State private var confirmClear = false

    private var shade: DecorShade {
        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .system, scheme: systemScheme)
    }

    var body: some View {
        ZStack {
            GlowBackground(shade: shade).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    groupTitle("外观")
                    group {
                        themeCards
                    }
                    groupTitle("会话页")
                    group {
                        Toggle(isOn: $statusbarFollowRemote) {
                            Text("状态栏跟随远程页面")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(GlassStyle.text(shade))
                        }
                        .tint(GlassStyle.accent)
                        .padding(16)
                    }
                    groupTitle("数据")
                    group {
                        Button {
                            confirmClear = true
                        } label: {
                            HStack {
                                Text("清除所有连接")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.red)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(GlassStyle.secondary(shade).opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                    }
                    groupTitle("关于")
                    group {
                        HStack {
                            Text("版本").font(.system(size: 15, weight: .medium))
                                .foregroundStyle(GlassStyle.text(shade))
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                                .font(.system(size: 13))
                                .foregroundStyle(GlassStyle.secondary(shade))
                        }
                        .padding(16)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("清除所有连接？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("确认清除", role: .destructive) {
                store.connections.forEach { store.delete($0) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除全部 \(store.connections.count) 条连接及其凭证，无法恢复。")
        }
    }

    /// 主题三选一卡片
    private var themeCards: some View {
        HStack(spacing: 8) {
            themeCard(DecorTheme.system, label: "跟随系统", icon: "circle.lefthalf.filled")
            themeCard(DecorTheme.light, label: "浅色", icon: "sun.max")
            themeCard(DecorTheme.dark, label: "深色", icon: "moon")
        }
        .padding(12)
    }

    private func themeCard(_ theme: DecorTheme, label: String, icon: String) -> some View {
        let selected = (DecorTheme(rawValue: decorRaw) ?? .system) == theme
        return Button {
            decorRaw = theme.rawValue
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label).font(.system(size: 11.5, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(selected ? GlassStyle.accent : GlassStyle.secondary(shade))
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? GlassStyle.accentSoft : Color.clear)
            )
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? GlassStyle.accent : GlassStyle.stroke(shade).opacity(0.5),
                              lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func groupTitle(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(GlassStyle.secondary(shade))
            .tracking(1)
            .padding(.leading, 6)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .background(GlassStyle.material(shade), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .strokeBorder(GlassStyle.stroke(shade), lineWidth: 1))
    }
}
