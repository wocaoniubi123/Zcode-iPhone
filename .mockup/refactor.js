// 批量改造脚本：两档主题/实底/删自动进远程
const fs = require('fs');
const edit = (p, pairs) => {
  let s = fs.readFileSync(p, 'utf8');
  for (const [a, b] of pairs) {
    if (!s.includes(a)) { console.error(`!! ${p} 找不到: ${JSON.stringify(a.slice(0, 70))}`); process.exit(1); }
    s = s.replace(a, b);
  }
  fs.writeFileSync(p, s);
  console.log('OK', p);
};

// RootView：shade 新签名 + 删自动进远程
edit('ZCodeShell/ZCodeShell/Views/RootView.swift', [
  ['    @Environment(\\.colorScheme) private var systemScheme\n', ''],
  ['    @State private var didAutoOpen = false\n', ''],
  ['        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .system, scheme: systemScheme)',
   '        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .light)'],
  ['        .onAppear {\n            guard !didAutoOpen, let last = store.lastConnection else { return }\n            didAutoOpen = true\n            path.append(last)\n        }\n    }', '    }'],
]);

// SettingsView：shade 新签名
edit('ZCodeShell/ZCodeShell/Views/SettingsView.swift', [
  ['    @Environment(\\.colorScheme) private var systemScheme\n', ''],
  ['        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .system, scheme: systemScheme)',
   '        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .light)'],
]);

// MainShellView：shade 新签名
edit('ZCodeShell/ZCodeShell/App/ZCodeShellApp.swift', [
  ['    @Environment(\\.colorScheme) private var systemScheme\n', ''],
  ['        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .system, scheme: systemScheme)',
   '        GlassStyle.shade(DecorTheme(rawValue: decorRaw) ?? .light)'],
]);
