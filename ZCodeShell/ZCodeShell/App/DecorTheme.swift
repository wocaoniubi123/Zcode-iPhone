import SwiftUI

/// 装饰层主题（纯视觉图层）：与底层功能颜色完全隔离，自带整页实底。
/// 只有两档，彻底脱离系统配色。
enum DecorTheme: String, CaseIterable, Identifiable {
    case light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var symbol: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var shade: DecorShade {
        self == .light ? .light : .dark
    }

    /// 装饰层整页实底色：深色全屏黑 / 浅色全屏白
    var canvasColor: Color {
        self == .light ? Color(white: 0.965) : Color(white: 0.045)
    }

    static let key = "zcode.decorTheme.v1"
}

/// 玻璃材质与配色常量（装饰层专用，不碰底层颜色）。
/// 装饰层明暗（材质选黑玻璃还是白玻璃用）。
enum DecorShade {
    case light, dark
}

/// 玻璃材质与配色常量（装饰层专用，不碰底层颜色）。
enum GlassStyle {
    /// 装饰层明暗直接来自主题档位（不再读系统色）
    static func shade(_ theme: DecorTheme) -> DecorShade {
        theme.shade
    }

    /// 装饰层整页实底
    static func canvas(_ theme: DecorTheme) -> Color {
        theme.canvasColor
    }

    // 琥珀点缀（品牌色，两套主题共用）
    static let accent = Color(red: 0.96, green: 0.62, blue: 0.04)   // #f59e0b
    static let accentSoft = accent.opacity(0.14)

    /// 卡片/菜单/tab 的背景：自定义玻璃材质（不依赖系统 colorScheme，跟装饰层 shade 走）
    /// 深色=暗玻璃，浅色=亮玻璃；半透明+高光内描边模拟液态玻璃
    static func glassBackground(_ shade: DecorShade) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(shade == .dark
                      ? Color(white: 0.11).opacity(0.72)
                      : Color(white: 0.98).opacity(0.72))
            // 顶部高光渐变：玻璃"受光"感
            LinearGradient(colors: shade == .dark
                           ? [Color.white.opacity(0.14), Color.white.opacity(0.02)]
                           : [Color.white.opacity(0.85), Color.white.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    static func glassFillColor(_ shade: DecorShade) -> Color {
        shade == .dark ? Color(white: 0.11).opacity(0.72) : Color(white: 0.98).opacity(0.72)
    }

    static func glassHighlight(_ shade: DecorShade) -> LinearGradient {
        LinearGradient(colors: shade == .dark
                       ? [Color.white.opacity(0.14), Color.white.opacity(0.02)]
                       : [Color.white.opacity(0.85), Color.white.opacity(0.25)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// 悬浮阴影
    static func floatShadow(_ shade: DecorShade) -> Color {
        shade == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.14)
    }

    /// 描边
    static func stroke(_ shade: DecorShade) -> Color {
        shade == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.65)
    }

    /// 主文字
    static func text(_ shade: DecorShade) -> Color {
        shade == .dark ? Color(white: 0.96) : Color(white: 0.06)
    }

    /// 次要文字
    static func secondary(_ shade: DecorShade) -> Color {
        shade == .dark ? Color(white: 0.62) : Color(white: 0.45)
    }

    /// 背景装饰光斑（给玻璃透出内容感）
    static func glow(_ shade: DecorShade) -> [Color] {
        shade == .dark
            ? [Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.20),
               Color(red: 0.04, green: 0.52, blue: 1.00).opacity(0.16)]
            : [Color(red: 1.00, green: 0.84, blue: 0.48).opacity(0.4),
               Color(red: 0.65, green: 0.85, blue: 1.00).opacity(0.35)]
    }

    /// 头像渐变（按连接名 hash 稳定选色）
    static func avatarGradient(_ name: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.98, green: 0.78, blue: 0.28), Color(red: 0.96, green: 0.62, blue: 0.04)],   // 琥珀
            [Color(red: 0.22, green: 0.74, blue: 0.97), Color(red: 0.01, green: 0.52, blue: 0.78)],   // 天蓝
            [Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.49, green: 0.23, blue: 0.93)],   // 紫
            [Color(red: 0.34, green: 0.80, blue: 0.62), Color(red: 0.13, green: 0.60, blue: 0.44)],   // 绿
            [Color(red: 0.98, green: 0.45, blue: 0.45), Color(red: 0.86, green: 0.21, blue: 0.27)],   // 红
            [Color(red: 0.45, green: 0.48, blue: 0.55), Color(red: 0.20, green: 0.22, blue: 0.27)],   // 石墨
        ]
        let idx = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % palettes.count
        return palettes[idx]
    }
}

/// 底层装饰光斑：给玻璃材质提供透出的内容感（纯装饰，不参与功能）
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
