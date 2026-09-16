import SwiftUI
import UIKit

/// 窗口级宿主：实底色与配色 override 都铺在 UIWindow 上，
/// SwiftUI 层之下，永不露缝（滚动回弹/亚像素误差都碰不到它）。
@MainActor
final class WindowHost {
    static let shared = WindowHost()

    /// 当前窗口配色来源（用于三态直切）：远程主题 or 装饰主题
    enum StyleSource {
        case remote(dark: Bool)
        case decor(DecorTheme)
    }

    private(set) var currentSource: StyleSource = .decor(.light)

    func apply(_ source: StyleSource) {
        currentSource = source
        let style: UIUserInterfaceStyle
        let bg: UIColor
        switch source {
        case .remote(let dark):
            style = dark ? .dark : .light
            // 远程态：底色给页面主题同族的深/浅， WebView 画布盖在上面，边界处不露异色
            bg = dark ? UIColor(red: 0.086, green: 0.086, blue: 0.086, alpha: 1)   // #161616
                      : UIColor(white: 0.98, alpha: 1)
        case .decor(let theme):
            style = theme == .dark ? .dark : .light
            bg = theme == .dark ? UIColor(white: 0.045, alpha: 1) : UIColor(white: 0.965, alpha: 1)
        }
        foreachKeyWindow { window in
            window.overrideUserInterfaceStyle = style
            window.backgroundColor = bg
        }
    }

    private func foreachKeyWindow(_ body: (UIWindow) -> Void) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes where scene.activationState == .foregroundActive || scenes.count == 1 {
            for window in scene.windows where window.isKeyWindow {
                body(window)
            }
        }
    }
}
