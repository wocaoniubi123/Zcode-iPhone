import SwiftUI
import UIKit

/// 粘贴官方链接添加（二维码和链接内容相同，粘链接等效扫码）。
struct ManualAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var raw = ""
    @State private var error: String?

    let onAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $raw)
                        .frame(minHeight: 100)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.footnote)
                } header: {
                    Text("ZCode 官方远程链接")
                } footer: {
                    Text("PC 端 ZCode「远程连接」给出的 https://…zcode.z.ai/remote/… 链接，与二维码内容相同，二选一即可。")
                }
                Section {
                    Button("从剪贴板粘贴") {
                        if let s = UIPasteboard.general.string { raw = s }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
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
                        guard ConnectionParser.parse(raw) != nil else {
                            error = "链接格式不对：需为 https://…zcode.z.ai/remote/…"
                            return
                        }
                        onAdd(raw)
                    }
                    .disabled(raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
