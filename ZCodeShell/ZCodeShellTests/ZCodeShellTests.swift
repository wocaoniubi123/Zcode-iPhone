import XCTest
@testable import ZCodeShell

final class ConnectionParserTests: XCTestCase {

    func testParseValidURL() {
        let raw = "zcode://192.168.1.10:8787?token=abcdef0123456789"
        guard let (conn, token) = ConnectionParser.parse(raw) else {
            return XCTFail("合法 URL 应解析成功")
        }
        XCTAssertEqual(conn.host, "192.168.1.10")
        XCTAssertEqual(conn.port, 8787)
        XCTAssertEqual(conn.useTLS, false)
        XCTAssertEqual(token, "abcdef0123456789")
        XCTAssertEqual(conn.name, "192.168.1.10:8787")
    }

    func testParseTLSViaScheme() {
        let (conn, _) = ConnectionParser.parse("zcodes://10.0.0.2:9443?token=abcdef0123456789")!
        XCTAssertEqual(conn.useTLS, true)
    }

    func testParseTLSViaQuery() {
        let (conn, _) = ConnectionParser.parse("zcode://10.0.0.2:8787?token=abcdef0123456789&tls=1")!
        XCTAssertEqual(conn.useTLS, true)
    }

    func testRejectUnknownScheme() {
        XCTAssertNil(ConnectionParser.parse("https://192.168.1.10:8787?token=abcdef0123456789"))
        XCTAssertNil(ConnectionParser.parse("http://192.168.1.10:8787?token=abcdef0123456789"))
    }

    func testRejectShortToken() {
        XCTAssertNil(ConnectionParser.parse("zcode://192.168.1.10:8787?token=abc"))
        XCTAssertNil(ConnectionParser.parse("zcode://192.168.1.10:8787"))
    }

    func testRejectBadPortAndEmptyHost() {
        XCTAssertNil(ConnectionParser.parse("zcode://192.168.1.10:99999?token=abcdef0123456789"))
        XCTAssertNil(ConnectionParser.parse("zcode://:8787?token=abcdef0123456789"))
    }

    func testWebSocketURLBuilding() {
        let (conn, _) = ConnectionParser.parse("zcode://192.168.1.10:8787?token=abcdef0123456789")!
        XCTAssertEqual(conn.webSocketURL?.absoluteString, "ws://192.168.1.10:8787")
        let (tlsConn, _) = ConnectionParser.parse("zcodes://192.168.1.10:8787?token=abcdef0123456789")!
        XCTAssertEqual(tlsConn.webSocketURL?.absoluteString, "wss://192.168.1.10:8787")
    }
}

final class SessionMessageTests: XCTestCase {

    func testDecodeBridgeMessages() throws {
        let output = try JSONDecoder().decode(BridgeMessage.self,
            from: Data(#"{"type":"output","text":"hello\n"}"#.utf8))
        XCTAssertEqual(output.type, "output")
        XCTAssertEqual(output.text, "hello\n")

        let exit = try JSONDecoder().decode(BridgeMessage.self,
            from: Data(#"{"type":"exit","code":0}"#.utf8))
        XCTAssertEqual(exit.code, 0)

        let err = try JSONDecoder().decode(BridgeMessage.self,
            from: Data(#"{"type":"error","message":"token 无效"}"#.utf8))
        XCTAssertEqual(err.message, "token 无效")

        let welcome = try JSONDecoder().decode(BridgeMessage.self,
            from: Data(#"{"type":"welcome","version":"1"}"#.utf8))
        XCTAssertEqual(welcome.type, "welcome")
    }

    func testEncodeClientMessages() throws {
        // send 消息必须能被 JSONSerialization 产出且含 type/text
        let dict: [String: Any] = ["type": "send", "text": "你好 zcode"]
        let data = try JSONSerialization.data(withJSONObject: dict)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["type"] as? String, "send")
        XCTAssertEqual(obj?["text"] as? String, "你好 zcode")
    }
}
