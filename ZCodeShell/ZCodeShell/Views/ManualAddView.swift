import SwiftUI

/// 手动添加连接：host/port/TLS 开关/token。扫码失败兜底或无码时用。
struct ManualAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var port = "8787"
    @State private var useTLS = false
    @State private var token = ""
    @State private var showRawPaste = false
    @State private var rawURL = ""

    let onAdd: (String, Int, Bool, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("主机（如 192.168.1.10）", text: $host)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    Toggle("TLS (wss)", isOn: $useTLS)
                }
                Section("Token") {
                    SecureField("bridge token（.zcode-bridge-token 文件内容）", text: $token)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("粘贴 zcode:// 链接解析") { showRawPaste = true }
                }
            }
            .navigationTitle("添加连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        guard let p = Int(port), (1...65535).contains(p), !host.isEmpty else { return }
                        onAdd(host, p, useTLS, token)
                    }
                    .disabled(host.isEmpty || Int(port) == nil)
                }
            }
            .alert("粘贴链接", isPresented: $showRawPaste) {
                TextField("zcode://192.168.1.10:8787?token=…", text: $rawURL)
                Button("解析") {
                    if let (conn, tk) = ConnectionParser.parse(rawURL) {
                        host = conn.host
                        port = String(conn.port)
                        useTLS = conn.useTLS
                        token = tk
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}
