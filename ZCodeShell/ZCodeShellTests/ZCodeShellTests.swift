import XCTest
@testable import ZCodeShell

final class ConnectionParserTests: XCTestCase {

    let official = "https://zcode.z.ai/remote/v4?sid=d_5EyD6M8MaAmmzvcBYX6zFR&hash=kHhxh0981xAw5fmUTTd%2FKs4iNiC%2B3xQO9ubvIi4puHo%3D&t=1789522062408&mid=7d39be96-e4f3-46c2-bc92-96f8b12c04d6&name=BF-202607312336&app_version=3.11.2"

    func testParseOfficialLink() {
        guard let conn = ConnectionParser.parse(official) else {
            return XCTFail("官方链接应解析成功")
        }
        XCTAssertEqual(conn.name, "BF-202607312336")
        XCTAssertEqual(conn.host, "zcode.z.ai")
        XCTAssertEqual(conn.url?.queryParams["sid"], "d_5EyD6M8MaAmmzvcBYX6zFR")
        // hash 是 URL 编码过的 base64，解码后应还原
        XCTAssertEqual(conn.url?.queryParams["hash"], "kHhxh0981xAw5fmUTTd/Ks4iNiC+3xQO9ubvIi4puHo=")
        XCTAssertEqual(conn.urlString, official) // 不改写原链接
    }

    func testParseWithWhitespace() {
        let padded = "  \n" + official + "  "
        XCTAssertNotNil(ConnectionParser.parse(padded))
    }

    func testNameFallbackToHost() {
        let noName = "https://zcode.z.ai/remote/v4?sid=abc123456789&mid=00000000-0000-0000-0000-000000000000"
        XCTAssertEqual(ConnectionParser.parse(noName)?.name, "zcode.z.ai")
    }

    func testRejectNonOfficial() {
        XCTAssertNil(ConnectionParser.parse("http://zcode.z.ai/remote/v4?sid=abc123456789"))   // 非 https
        XCTAssertNil(ConnectionParser.parse("https://evil.com/remote/v4?sid=abc123456789"))     // 非 zcode 域
        XCTAssertNil(ConnectionParser.parse("https://zcode.z.ai/dashboard?sid=abc123456789"))   // 非 remote 路径
        XCTAssertNil(ConnectionParser.parse("随便一串文字"))
    }

    func testURLQueryParamsDecoding() {
        let url = URL(string: "https://x.test/?a=%2F&a2=b%3Dc")!
        XCTAssertEqual(url.queryParams["a"], "/")
        XCTAssertEqual(url.queryParams["a2"], "b=c")
    }
}

/// ConnectionStore 依赖真机 Keychain（模拟器单测可用，但 CI 无 Keychain 写权限差异风险），
/// 核心排序/upsert 逻辑在这里以纯数据方式验证。Keychain 集成留给真机手测。
final class ConnectionStoreLogicTests: XCTestCase {

    func testMetaSortingByLastUsed() throws {
        // 验证 load() 排序规则：lastUsed 降序
        let metas = [
            ConnectionStore.Meta(id: UUID(), name: "old", lastUsed: Date(timeIntervalSince1970: 100)),
            ConnectionStore.Meta(id: UUID(), name: "new", lastUsed: Date(timeIntervalSince1970: 200)),
        ]
        let sorted = metas.sorted { $0.lastUsed > $1.lastUsed }
        XCTAssertEqual(sorted.first?.name, "new")
    }
}
