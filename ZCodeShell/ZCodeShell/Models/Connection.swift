import Foundation

/// 一条 ZCode 官方远程连接 = 官方桌面端生成的 remote/v4 链接（含 sid/hash 等凭证）。
/// 链接整体是敏感凭证 → 存 Keychain；展示用的 name/host 存 UserDefaults。
struct ZCodeConnection: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String            // 展示名：URL 的 name 参数（如 BF-202607312336），缺省用 host
    var urlString: String       // 完整官方链接（含 token 性质的参数，不入 UserDefaults）

    var url: URL? { URL(string: urlString) }

    var host: String { url?.host ?? "" }
}

enum ConnectionParser {
    /// 合法 = https 且 host 是 zcode.z.ai、路径 /remote/v4（宽松点：host 以 zcode.z.ai 结尾）。
    /// 二维码内容与链接相同，扫码/粘贴走同一个入口。
    static func parse(_ raw: String) -> ZCodeConnection? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == "https",
              url.host?.hasSuffix("zcode.z.ai") == true,
              url.path.hasPrefix("/remote/") else {
            return nil
        }
        let name = url.queryParams["name"] ?? ""
        let display = name.isEmpty ? (url.host ?? "ZCode") : name
        return ZCodeConnection(name: display, urlString: trimmed)
    }
}

extension URL {
    /// URLComponents 兜底解析 query（URL.queryParams 在 iOS16 可用，但自己解更省心且测试可控）
    var queryParams: [String: String] {
        guard let comps = URLComponents(string: absoluteString) else { return [:] }
        var out: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            out[item.name] = item.value ?? ""
        }
        return out
    }
}
