import Foundation

/// 一条已保存的 ZCode 连接（PC 端 bridge）。
/// 持久化：地址等非敏感字段存 UserDefaults，token 存 Keychain。
struct ZCodeConnection: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String            // 显示名，默认 host:port
    var host: String
    var port: Int
    var useTLS: Bool            // true → wss://（自签证书时 app 侧放行）
    var lastUsed: Date

    var webSocketURL: URL? {
        var comps = URLComponents()
        comps.scheme = useTLS ? "wss" : "ws"
        comps.host = host
        comps.port = port
        return comps.url
    }

    var displayAddress: String {
        let scheme = useTLS ? "zcodes" : "zcode"
        return "\(scheme)://\(host):\(port)"
    }
}

/// 扫码 URL 解析：zcode://host:port?token=hex  /  zcodes://...?token=hex&tls=1
enum ConnectionParser {
    static let schemes = ["zcode", "zcodes"]

    /// 返回 (连接信息, token)。格式非法返回 nil。
    static func parse(_ raw: String) -> (connection: ZCodeConnection, token: String)? {
        guard let comps = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = comps.scheme?.lowercased(),
              schemes.contains(scheme),
              let host = comps.host, !host.isEmpty,
              let port = comps.port,
              (1...65535).contains(port) else {
            return nil
        }
        let token = comps.queryItems?.first(where: { $0.name == "token" })?.value ?? ""
        guard token.count >= 16 else { return nil } // token 必须 64 hex，这里放宽为长度下限防误扫
        let useTLS = (scheme == "zcodes") || (comps.queryItems?.first(where: { $0.name == "tls" })?.value == "1")
        let conn = ZCodeConnection(
            name: "\(host):\(port)",
            host: host,
            port: port,
            useTLS: useTLS,
            lastUsed: Date()
        )
        return (conn, token)
    }
}
