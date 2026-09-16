// mockup v3 生成器：右上角 + 菜单收纳扫码/粘贴
const fs = require('fs');
const p = '.mockup/preview.html';
let h = fs.readFileSync(p, 'utf8');

// ── 样式：+ 按钮 与 弹出菜单 ──
h = h.replace('.a-addbtn svg { width:18px; height:18px; }', `
  .icn.a-plus, .icn.b-plus { font-size:23px; font-weight:500; line-height:1; }
  .a-plus { background:#0a84ff; color:#fff; box-shadow:0 3px 10px rgba(10,132,255,.35); }
  .b-plus { background:linear-gradient(145deg,#ffc848,#f59e0b); color:#1a1a1c; box-shadow:0 3px 12px rgba(245,158,11,.4); }
  .menu-pop { position:absolute; top:92px; right:16px; z-index:20; border-radius:13px; overflow:hidden;
    width:200px; box-shadow:0 10px 34px rgba(0,0,0,.35); font-size:14.5px; }
  .menu-pop .mi { display:flex; align-items:center; gap:10px; padding:11px 14px; font-weight:550; }
  .menu-pop .mi svg { width:17px; height:17px; flex-shrink:0; }
  .menu-pop .mi + .mi { border-top:1px solid rgba(128,128,128,.18); }
  .menu-a { background:rgba(250,250,252,.97); color:#111; }
  .menu-b { background:rgba(30,30,34,.97); color:#fff; border:1px solid #2c2c31; }
  .menu-arrow { position:absolute; top:82px; right:26px; width:14px; height:14px; transform:rotate(45deg); z-index:19; }
  .arrow-a { background:#fafafc; }
  .arrow-b { background:#1e1e22; border:1px solid #2c2c31; }
  .a-addbtn svg { width:18px; height:18px; }`);

const scanSVG = (color) => `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:17px;height:17px"><path d="M3 8V5a2 2 0 0 1 2-2h3M16 3h3a2 2 0 0 1 2 2v3M21 16v3a2 2 0 0 1-2 2h-3M8 21H5a2 2 0 0 1-2-2v-3"/><rect x="8.2" y="8.2" width="7.6" height="7.6" rx="1.4"/></svg>`;
const pasteSVG = (color) => `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:17px;height:17px"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect x="8" y="2" width="8" height="4" rx="1"/></svg>`;

const menu = (cls, scanColor, pasteColor) => `
  <div class="menu-arrow arrow-${cls === 'a' ? 'a' : 'b'}"></div>
  <div class="menu-pop menu-${cls}">
    <div class="mi">${scanSVG(scanColor)}扫码连接</div>
    <div class="mi">${pasteSVG(pasteColor)}粘贴链接</div>
  </div>`;

// ── 方案 A：右上 + 钮（替换原粘贴小图标），删底部按钮排，插菜单 ──
h = h.replace('<div class="a-navbtns">\n        <div class="icn a-icn" title="粘贴链接">',
              `<div class="a-navbtns">\n        ${menu('a', '#0a84ff', '#8e8e93')}\n        <div class="icn a-plus" title="添加">+</div>`);
h = h.replace(/<div class="a-addrow">[\s\S]*?<\/div>\s*\n\s*<\/div>\s*\n\s*<div class="homebar" style="background:#000"><\/div>/,
              '<div class="homebar" style="background:#000"></div>');

// ── 方案 B：右上 + 钮，删底部按钮排，插菜单 ──
h = h.replace('<div class="b-navbtns">\n          <div class="icn b-icn" title="粘贴链接">',
              `<div class="b-navbtns">\n          ${menu('b', '#f59e0b', '#a0a0a8')}\n          <div class="icn b-plus" title="添加">+</div>`);
h = h.replace(/<div class="b-addrow">[\s\S]*?<div class="b-homehint">/,
              '<div class="b-homehint" style="padding-top:6px">');

fs.writeFileSync(p, h);
console.log('v3 写完：右上 + 弹出菜单版');
