import SwiftUI
import UIKit

/// 外观偏好：跟随系统 / 浅色 / 深色。存 UserDefaults，App 级生效（含 WebView）。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// WKWebView 用：overrideUserInterfaceStyle 的 UIUserInterfaceStyle 值
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    static let key = "zcode.appearance.v1"
    static var current: AppearanceMode {
        AppearanceMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system
    }
    static func save(_ m: AppearanceMode) {
        UserDefaults.standard.set(m.rawValue, forKey: key)
    }
}
