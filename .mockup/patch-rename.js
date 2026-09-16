// 接 onRename 调用点 + 重命名弹窗
const fs = require('fs');
const p = 'ZCodeShell/ZCodeShell/Views/RootView.swift';
let s = fs.readFileSync(p, 'utf8');

const a1 = 'SwipeToDeleteCard(shade: shade,\n                                                      onDelete: { pendingDelete = meta }) {';
const b1 = 'SwipeToDeleteCard(shade: shade,\n                                                      onRename: { renameTarget = meta; renameText = meta.name },\n                                                      onDelete: { pendingDelete = meta }) {';

const a2 = '    @State private var pendingDelete: ConnectionStore.Meta?';
const b2 = `    @State private var pendingDelete: ConnectionStore.Meta?
    @State private var renameTarget: ConnectionStore.Meta?
    @State private var renameText = ""`;

// 用行级定位 confirmationDialog（避免 \\( 转义地狱）
const lines = s.split('\n');
const idx = lines.findIndex(l => l.includes('.confirmationDialog("删除连接'));
if (idx < 0) { console.error('!! 找不到 confirmationDialog 行'); process.exit(1); }
const alertBlock = [
  '        .alert("重命名连接", isPresented: Binding(get: { renameTarget != nil },',
  '                                             set: { if !$0 { renameTarget = nil } })) {',
  '            TextField("连接名称", text: $renameText)',
  '            Button("保存") {',
  '                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)',
  '                if let m = renameTarget, !name.isEmpty { store.rename(m, to: name) }',
  '                renameTarget = nil',
  '            }',
  '            Button("取消", role: .cancel) { renameTarget = nil }',
  '        } message: {',
  '            Text("仅改显示名，不影响远程连接本身。")',
  '        }',
].join('\n');
lines.splice(idx, 0, alertBlock);
s = lines.join('\n');

for (const [a, b] of [[a1, b1], [a2, b2]]) {
  if (!s.includes(a)) { console.error('!! 找不到:', JSON.stringify(a.slice(0, 70))); process.exit(1); }
  s = s.replace(a, b);
}
fs.writeFileSync(p, s);
console.log('RootView OK');
