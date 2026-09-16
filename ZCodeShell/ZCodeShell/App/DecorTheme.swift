import SwiftUI

/// 装饰层主题（纯视觉图层）：跟底层功能颜色完全隔离。
/// 三选一持久化；"跟随系统"按系统深浅解析出具体材质。
enum DecorTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    static let key = "zcode.decorTheme.v1"
}

/// 装饰层解析后的明暗（材质选黑玻璃还是白玻璃用）。
enum DecorShade {
    case light, dark
}

/// 玻璃材质与配色常量（装饰层专用，不碰底层颜色）。
enum GlassStyle {
    /// 装饰层当前明暗：主题设置 + 系统色 scheme 解析
    static func shade(_ theme: DecorTheme, scheme: ColorScheme?) -> DecorShade {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return scheme == .dark ? .dark : .light
        }
    }

    // 琥珀点缀（品牌色，两套主题共用）
    static let accent = Color(red: 0.96, green: 0.62, blue: 0.04)   // #f59e0b
    static let accentSoft = accent.opacity(0.14)

    /// 卡片/菜单/tab 的背景材质
    static func material(_ shade: DecorShade) -> Material {
        shade == .dark ? .ultraThinMaterial : .regularMaterial
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
