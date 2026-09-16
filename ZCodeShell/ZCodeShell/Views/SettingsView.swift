import SwiftUI

/// 设置页（装饰层）：主题两档（浅色/深色）/ 清除连接（二次确认）/ 版本。
struct SettingsView: View {
    @EnvironmentObject private var store: ConnectionStore
    @AppStorage(DecorTheme.key) private var decorRaw = DecorTheme.light.rawValue
    @State private var confirmClear = false

    private var theme: DecorTheme {
        DecorTheme(rawValue: decorRaw) ?? .light
    }

    private var shade: DecorShade {
        GlassStyle.shade(theme)
    }

    var body: some View {
        ZStack {
            GlassStyle.canvas(theme).ignoresSafeArea()
            GlowBackground(shade: shade).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("设置")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(GlassStyle.text(shade))
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)
                    groupTitle("外观")
                    group {
                        themeCards
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("清除所有连接？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("确认清除", role: .destructive) {
                store.connections.forEach { store.delete($0) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除全部 \(store.connections.count) 条连接及其凭证，无法恢复。")
        }
    }

    /// 主题两档卡片（浅色/深色，彻底脱离系统配色）
    private var themeCards: some View {
        HStack(spacing: 8) {
            themeCard(DecorTheme.light, label: "浅色", icon: "sun.max")
            themeCard(DecorTheme.dark, label: "深色", icon: "moon")
        }
        .padding(12)
    }

    private func themeCard(_ theme: DecorTheme, label: String, icon: String) -> some View {
        let selected = (DecorTheme(rawValue: decorRaw) ?? .light) == theme
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
}
