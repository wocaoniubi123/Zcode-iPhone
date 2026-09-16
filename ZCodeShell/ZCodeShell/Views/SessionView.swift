import SwiftUI

/// 会话页：状态栏 + 对话流 + 输入框。进入即连接，退出即断开。
struct SessionView: View {
    @StateObject private var model: SessionModel
    @Environment(\.dismiss) private var dismiss

    init(model: SessionModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBanner
            transcriptList
            inputBar
        }
        .background(Color(.systemBackground))
        .navigationTitle(model.connection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("重新连接") { model.stop(); model.start() }
                    Button("发送 ping", role: .destructive) { model.sendPing() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var statusBanner: some View {
        HStack(spacing: 8) {
            switch model.phase {
            case .idle:
                Image(systemName: "pause.circle").foregroundStyle(.secondary)
                Text("未连接").foregroundStyle(.secondary)
            case .connecting(let attempt):
                ProgressView()
                Text(attempt > 1 ? "重连中…(第 \(attempt) 次)" : "连接中…")
                    .foregroundStyle(.orange)
            case .connected:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("已连接 \(model.connection.displayAddress)")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(message).foregroundStyle(.red)
            }
            Spacer()
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(model.transcript) { line in
                        Text(line.text)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(line.isMine ? Color.blue.opacity(0.12) : .clear)
                            .id(line.id)
                    }
                    // 跨包未结尾的残余输出也显示
                    if !model.pendingTail.isEmpty {
                        Text(model.pendingTail)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .id("pendingTail")
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: model.transcript.count) { _ in
                if let last = model.transcript.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("输入消息…", text: $model.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit { model.send() }
            Button {
                model.send()
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || model.phase != .connected)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
    }
}
