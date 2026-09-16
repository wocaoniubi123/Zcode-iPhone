import Foundation

/// WebSocket 会话：连接 bridge，收发 JSON 消息。
/// - 自动重连：指数退避 1s→2s→…→上限 30s，可手动停止
/// - TLS：wss 时允许自签证书（自用局域网桥，证书不校验）
@MainActor
final class SessionModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case connecting(attempt: Int)
        case connected
        case failed(message: String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcript: [ChatLine] = []
    @Published private(set) var pendingTail: String = ""   // 跨行残余输出（未遇 \n）
    @Published var draft: String = ""

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var shouldReconnect = true
    /// 强持有 delegate：URLSession 对 delegate 是弱引用，局部变量会当场释放导致 TLS 回调丢失
    private var delegateRetainer: TLSPassthroughDelegate?

    let connection: ZCodeConnection
    private let tokenProvider: () -> String?

    struct ChatLine: Identifiable, Equatable {
        let id = UUID()
        let isMine: Bool
        let text: String
        let time: Date
    }

    init(connection: ZCodeConnection, tokenProvider: @escaping () -> String?) {
        self.connection = connection
        self.tokenProvider = tokenProvider
    }

    // MARK: - 生命周期

    func start() {
        // 手动启动入口：只在空闲/失败态起步；重连走 scheduleReconnect()，不经过这里
        guard phase == .idle || isFailure else { return }
        shouldReconnect = true
        reconnectAttempt = 0
        connect()
    }

    func stop() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        delegateRetainer = nil
        phase = .idle
    }

    private var isFailure: Bool {
        if case .failed = phase { return true } else { return false }
    }

    private func connect() {
        guard let url = connection.webSocketURL else {
            phase = .failed(message: "地址无效")
            return
        }
        guard let token = tokenProvider(), !token.isEmpty else {
            phase = .failed(message: "缺少 token，请重新扫码")
            return
        }

        session?.invalidateAndCancel()
        let delegate = TLSPassthroughDelegate()   // 自签证书放行（自用）
        delegateRetainer = delegate
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let t = session!.webSocketTask(with: url)
        task = t
        phase = .connecting(attempt: reconnectAttempt + 1)
        t.resume()

        receiveLoop(on: t)
        // hello 握手
        t.send(.string(json(["type": "hello", "token": token]))) { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor [weak self] in
                self?.scheduleReconnect()
            }
        }
    }

    private func receiveLoop(on t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.task === t else { return }
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let s): self.handle(text: s)
                    case .data(let d): self.handle(text: String(data: d, encoding: .utf8) ?? "")
                    @unknown default: break
                    }
                    self.receiveLoop(on: t)
                case .failure:
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        // 去重：send 失败回调与 receive 失败可能同时触发
        if case .connecting = phase, reconnectTask != nil { return }
        guard shouldReconnect else {
            phase = .failed(message: "连接已断开")
            return
        }
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt - 1)), 30)
        phase = .connecting(attempt: reconnectAttempt)
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    // ponytail: 停止后需要再连时调 start()（stop 把 phase 归 idle，start 放行）

    // MARK: - 协议

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let msg = try? JSONDecoder().decode(BridgeMessage.self, from: data) else { return }
        switch msg.type {
        case "welcome":
            reconnectAttempt = 0
            phase = .connected
        case "output":
            appendRemote(text: msg.text ?? "")
        case "exit":
            appendRemote(text: "\n[zcode 进程退出，code=\(msg.code ?? 0)]\n")
        case "error":
            appendRemote(text: "\n[bridge 错误: \(msg.message ?? "?")]\n")
        case "pong":
            break
        default:
            break
        }
    }

    /// zcode 输出按到达顺序合并成对话行：跨包文本粘住，遇 \n 结行。
    private func appendRemote(text: String) {
        for ch in text {
            if ch == "\n" {
                transcript.append(ChatLine(isMine: false, text: pendingTail, time: Date()))
                pendingTail = ""
            } else {
                pendingTail.append(ch)
            }
        }
        trimTranscript()
    }

    private func trimTranscript() {
        if transcript.count > 2000 {
            transcript.removeFirst(transcript.count - 2000)
        }
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, phase == .connected, let task else { return }
        appendMine(text)
        draft = ""
        task.send(.string(json(["type": "send", "text": text]))) { _ in }
    }

    func sendPing() {
        task?.send(.string(json(["type": "ping"]))) { _ in }
    }

    private func appendMine(_ text: String) {
        transcript.append(ChatLine(isMine: true, text: text, time: Date()))
        trimTranscript()
    }

    private func json(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }
}

/// 服务端 bridge 消息（宽松解析：未知字段忽略）。
struct BridgeMessage: Decodable {
    let type: String
    let text: String?
    let message: String?
    let code: Int?
}

/// wss + 自签证书：放行服务端证书（仅自用局域网桥）。
final class TLSPassthroughDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
