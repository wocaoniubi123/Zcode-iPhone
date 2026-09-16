import Foundation
import Security

/// 连接仓库：
/// - 完整链接（含凭证）→ Keychain，逐条存取（service 固定，account=id）
/// - id/name/顺序 → UserDefaults（JSON 数组，不含凭证）
final class ConnectionStore: ObservableObject {
    static let shared = ConnectionStore()

    private let listKey = "zcode.connections.v2"
    private let lastIDKey = "zcode.lastConnectionID.v2"
    private let service = "zcode-shell.conn"
    private let defaults = UserDefaults.standard

    struct Meta: Codable {
        let id: UUID
        var name: String
        var lastUsed: Date
    }

    @Published private(set) var connections: [Meta] = []   // lastUsed 降序
    @Published private(set) var lastConnectionID: UUID?

    init() { load() }

    var lastConnection: Meta? { connections.first }

    func urlString(for meta: Meta) -> String? {
        KeychainStore.read(service: service, account: meta.id.uuidString)
    }

    /// 新增或按"同 sid+mid 视为同一条"更新。返回用于打开的 meta。
    @discardableResult
    func upsert(_ conn: ZCodeConnection) -> Meta {
        let sid = conn.url?.queryParams["sid"] ?? conn.urlString
        let mid = conn.url?.queryParams["mid"] ?? ""
        var meta = connections.first(where: { m in
            guard let s = urlString(for: m) else { return false }
            return (URL(string: s)?.queryParams["sid"] ?? s) == sid
                && (URL(string: s)?.queryParams["mid"] ?? "") == mid
        })
        if meta != nil {
            meta!.name = conn.name
        } else {
            meta = Meta(id: UUID(), name: conn.name, lastUsed: .distantPast)
        }
        var target = meta!
        KeychainStore.save(service: service, account: target.id.uuidString, value: conn.urlString)
        connections.removeAll(where: { $0.id == target.id })
        target.lastUsed = Date()
        connections.insert(target, at: 0)
        lastConnectionID = target.id
        persist()
        return target
    }

    func delete(_ meta: Meta) {
        KeychainStore.delete(service: service, account: meta.id.uuidString)
        connections.removeAll(where: { $0.id == meta.id })
        if lastConnectionID == meta.id { lastConnectionID = connections.first?.id }
        persist()
    }

    func touch(_ meta: Meta) {
        guard let idx = connections.firstIndex(where: { $0.id == meta.id }) else { return }
        connections[idx].lastUsed = Date()
        lastConnectionID = meta.id
        persist()
    }

    // MARK: - 持久化（UserDefaults 只存元数据，不存链接）

    private func load() {
        if let data = defaults.data(forKey: listKey),
           let list = try? JSONDecoder().decode([Meta].self, from: data) {
            connections = list.sorted { $0.lastUsed > $1.lastUsed }
        }
        if let raw = defaults.string(forKey: lastIDKey) { lastConnectionID = UUID(uuidString: raw) }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(connections) {
            defaults.set(data, forKey: listKey)
        }
        defaults.set(lastConnectionID?.uuidString, forKey: lastIDKey)
    }
}

/// Keychain 最小封装：kSecClassGenericPassword，按 (service, account) 存取删。
enum KeychainStore {
    private static let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword]

    static func save(service: String, account: String, value: String) {
        let query = base.merging([
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]) { _, new in new }
        let valueData = Data(value.utf8)
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary,
                          [kSecValueData as String: valueData] as CFDictionary)
        } else {
            var add = query
            add[kSecValueData as String] = valueData
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func read(service: String, account: String) -> String? {
        let query = base.merging([
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query = base.merging([
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]) { _, new in new }
        SecItemDelete(query as CFDictionary)
    }
}
