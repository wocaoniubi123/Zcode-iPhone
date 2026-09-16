# ZCode iPhone 壳

扫码/粘贴 **ZCode 官方远程链接** 连回 PC 的 iOS 壳（SwiftUI + WKWebView，无自建服务）。

```
PC 端 ZCode「远程连接」──► 生成二维码/链接（内容相同）
        https://zcode.z.ai/remote/v4?sid=…&hash=…&name=…
                    │  iPhone 壳：扫码 或 粘贴链接
                    ▼
            WKWebView 打开官方远程页面（会话全部由官方页面承载）
```

## 功能

- 扫码添加（相机）或粘贴链接添加，二选一，内容相同
- 连接持久化：完整链接存 Keychain（含凭证，不进 UserDefaults），最近使用置顶
- 打开 app 自动进入最近一条连接
- 多连接管理、左滑删除、链接非法提示

## 构建

```bash
# CI：push 即自动跑（GitHub Actions → build-ipa → 下载 artifact ZCodeShell-unsigned-ipa）
# 本地（需 macOS + xcodegen）:
cd ZCodeShell && xcodegen generate && ./scripts/build-ipa.sh dist
```

出的是 **unsigned IPA**，用 Sideloadly / AltStore + 自己的 Apple ID 重签安装。

## 已知边界

- 壳只负责“存链接 + 开官方页面”，远程协议/画面由 `zcode.z.ai` 官方页面自己实现
- 链接里的 hash/timeline 是官方凭证，官方如有过期机制需重新扫码获取新链接
- WKWebView 内如遇官方页面要求弹窗/下载等高级能力，按需再补 WKUIDelegate
