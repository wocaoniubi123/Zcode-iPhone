// 修 card() 大括号错位：删 245 行多余的 cardContent 闭合括号
const fs = require('fs');
const p = 'ZCodeShell/ZCodeShell/Views/RootView.swift';
let s = fs.readFileSync(p, 'utf8');

const a = `                    .foregroundStyle(GlassStyle.secondary(shade).opacity(0.6))
            }
            .padding(14)`;
const b = `                    .foregroundStyle(GlassStyle.secondary(shade).opacity(0.6))
            .padding(14)`;

if (!s.includes(a)) { console.error('!! not found'); process.exit(1); }
s = s.replace(a, b);

// 平衡校验（card() 函数体内）
const lines = s.split('\n');
let depth = 0;
for (let i = 211; i < 268; i++) {
  for (const ch of lines[i]) { if (ch === '{') depth++; else if (ch === '}') depth--; }
}
console.log('card() 末深度 =', depth, depth === 0 ? 'OK' : '仍不平衡');
fs.writeFileSync(p, s);
