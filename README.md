# ZCode iOS 壳

扫码连接局域网内 PC 上的 ZCode：iPhone 端原生壳（SwiftUI）+ PC 端桥接服务（Node，零依赖）。

```
iPhone 壳 ──扫码──► zcode://<IP>:8787?token=… ──► PC bridge (bridge.js) ──► zcode CLI
              └──────── WebSocket (ws:// 或 wss://) ────────┘
```

## 组成

| 部分 | 位置 | 说明 |
|------|------|------|
| PC 桥接 | `bridge/bridge.js` | Node 18+，零依赖。WS 服务 + token 鉴权 + 启停 zcode 子进程，输出按行推送 |
| 桥接自检 | `bridge/test-bridge.js` | 端到端：握手/鉴权错误/正确/ping-pong，`node bridge/test-bridge.js` |
| iOS 壳 | `ZCodeShell/` | SwiftUI。扫码 / 连接持久化（Keychain）/ 自动重连 / 会话 UI / 手动添加 / TLS |
| 工程生成 | `ZCodeShell/project.yml` | XcodeGen 定义，CI 生成 `.xcodeproj`，仓库里不存 pbxproj |
| CI | `.github/workflows/build-ipa.yml` | macOS runner：跑测试 → 出 unsigned IPA artifact |

## 快速开始

### 1. PC 端起 bridge

```bash
node bridge/bridge.js            # 默认 0.0.0.0:8787，自动打印连接 URL
# 可选: --port 9000  --tls --cert cert.pem --key key.pem  --zcode "自定义命令"
```

首次运行生成 `.zcode-bridge-token`（token 自动持久化，重启不变），终端打印：

```
zcode://192.168.x.x:8787?token=abcdef…
```

### 2. iPhone 装 app

1. push 到 GitHub → Actions 跑 `build-ipa` → 下载 artifact `ZCodeShell-unsigned-ipa`
2. Windows 上 [Sideloadly](https://sideloadly.io) 拖入 IPA + Apple ID 重签，数据线安装
3. 免费 Apple ID 签名 7 天过期，到期重签覆盖安装（连接记录保留）

### 3. 连接

打开 app → 扫 PC 终端上的二维码 → 自动保存并进入会话页。
下次打开 app 自动重连上次地址（失败自动重连，指数退避到 30s）。
也可在 app 内手动添加（左上角 +，支持粘贴 `zcode://` 链接解析）。

## 协议

一行一帧 JSON：

| 方向 | type | 字段 | 说明 |
|------|------|------|------|
| C→S | `hello` | `token` | 必须首帧，失败即断（1008） |
| C→S | `send` | `text` | 写入 zcode stdin（自动补 `\n`） |
| C→S | `ping` | — | 心跳 |
| S→C | `welcome` / `output` / `exit` / `error` / `pong` | `text`/`code`/`message` | 会话事件 |

安全：token 64-hex 随机，`timingSafeEqual` 比对；TLS 可选（自签证书 app 侧放行）；
bridge 只监听局域网时请勿暴露公网——它等于把 shell 交给了持 token 者。

## 已知边界（ponytail 债务）

- bridge 单会话：一个 WS 客户端独占一个 zcode 进程，断开即杀进程。多端并发需要会话池
- zcode 交互按行缓冲，无行尾的输出（如进度条）粘到下一帧
- iOS 后台约 30s 后 WS 会被系统挂起，回前台靠自动重连恢复
