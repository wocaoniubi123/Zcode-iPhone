import Foundation
import Security

/// 连接仓库：
/// - 连接元数据（JSON 数组）→ UserDefaults
/// - token（按连接 id）→ Keychain
/// 排序规则：lastUsed 降序，最近使用在前；第 0 条即"上次连接"。
final class ConnectionStore: ObservableObject {
    static let shared = ConnectionStore()

    private let listKey = "zcode.connections.v1"
    private let lastIDKey = "zcode.lastConnectionID.v1"
    private let defaults = UserDefaults.standard

    @Published private(set) var connections: [ZCodeConnection] = []
    @Published private(set) var lastConnectionID: UUID?

    init() {
        load()
    }

    // MARK: - 查询

    var lastConnection: ZCodeConnection? {
        guard let id = lastConnectionID else { return connections.first }
        return connections.first(where: { $0.id == id }) ?? connections.first
    }

    func token(for id: UUID) -> String? {
        KeychainStore.read(service: "zcode-shell", account: id.uuidString)
    }

    // MARK: - 增改

    /// 保存（upsert）并置为"最近使用"。同 host+port+tls 视为同一条，更新而非新增。
    @discardableResult
    func upsert(host: String, port: Int, useTLS: Bool, token: String) -> ZCodeConnection {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var conn = connections.first(where: {
            $0.host == trimmedHost && $0.port == port && $0.useTLS == useTLS
        })
        if conn != nil {
            conn!.lastUsed = Date()
            conn!.name = "\(trimmedHost):\(port)"
        } else {
            conn = ZCodeConnection(name: "\(trimmedHost):\(port)", host: trimmedHost,
                                   port: port, useTLS: useTLS, lastUsed: Date())
        }
        var target = conn!
        if !token.isEmpty {
            KeychainStore.save(service: "zcode-shell", account: target.id.uuidString, value: token)
        }
        connections.removeAll(where: { $0.id == target.id })
        connections.insert(target, at: 0)
        lastConnectionID = target.id
        persist()
        return target
    }

    func delete(_ conn: ZCodeConnection) {
        KeychainStore.delete(service: "zcode-shell", account: conn.id.uuidString)
        connections.removeAll(where: { $0.id == conn.id })
        if lastConnectionID == conn.id {
            lastConnectionID = connections.first?.id
        }
        persist()
    }

    func touch(_ conn: ZCodeConnection) {
        guard let idx = connections.firstIndex(where: { $0.id == conn.id }) else { return }
        connections[idx].lastUsed = Date()
        lastConnectionID = conn.id
        persist()
    }

    // MARK: - 持久化

    private func load() {
        if let data = defaults.data(forKey: listKey),
           let list = try? JSONDecoder().decode([ZCodeConnection].self, from: data) {
            connections = list.sorted { $0.lastUsed > $1.lastUsed }
        }
        if let raw = defaults.string(forKey: lastIDKey) {
            lastConnectionID = UUID(uuidString: raw)
        }
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
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword
    ]

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
        var query = base.merging([
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
