// mockup 追加设置页
const fs = require('fs');
const p = '.mockup/preview.html';
let h = fs.readFileSync(p, 'utf8');

const settingsCSS = `
  /* ── 设置页 ── */
  .set-list { flex:1; overflow:hidden; padding:10px 14px 0; position:relative; z-index:2; }
  .set-group { border-radius:20px; overflow:hidden; margin-bottom:14px; }
  .set-row { display:flex; align-items:center; gap:12px; padding:14px 16px; }
  .set-row + .set-row { border-top:1px solid rgba(128,128,128,.15); }
  .set-row .lbl { flex:1; font-size:15px; font-weight:550; }
  .set-row .val { font-size:13.5px; opacity:.5; }
  .set-title { font-size:11.5px; font-weight:700; opacity:.45; letter-spacing:1px; margin:6px 4px 9px; }
  .theme-demo { display:flex; gap:8px; padding:12px; }
  .theme-card { flex:1; border-radius:14px; padding:10px 6px; text-align:center; font-size:11.5px; font-weight:650; border:2px solid transparent; }
  .theme-card.on { border-color:#f59e0b; }
  .tc-light { background:#f4f4f7; color:#0a0a0c; }
  .tc-dark  { background:#17171a; color:#f5f5f7; }
  .tc-auto  { background:linear-gradient(120deg,#f4f4f7 50%,#17171a 50%); color:#fff; text-shadow:0 0 4px rgba(0,0,0,.8); }
  .set-toggle { width:44px; height:26px; border-radius:14px; background:rgba(120,120,128,.32); position:relative; flex-shrink:0; }
  .set-toggle i { position:absolute; top:2px; left:20px; width:22px; height:22px; border-radius:50%; background:#fff; box-shadow:0 1px 4px rgba(0,0,0,.3); }
  .set-toggle.on { background:#34c759; }
  .danger { color:#ff6b60; }
`;
h = h.replace('</style>', settingsCSS + '</style>');

const settingsPhone = `
<!-- ═══════ 设置页（黑主题态示意） ═══════ -->
<div class="col">
  <div class="phone"><div class="screen d-screen">
    <div class="notch"></div>
    <div class="bg-deco"><i></i><i></i></div>
    <div class="statusbar"><span>14:36</span><span class="right">▂▄▆ ᯤ <span class="battery"><i></i></span></span></div>
    <div class="top">
      <div><div class="big">设置</div></div>
    </div>
    <div class="set-list">
      <div class="set-title">外观</div>
      <div class="set-group glass">
        <div class="theme-demo">
          <div class="theme-card tc-auto on">◑<br>跟随系统</div>
          <div class="theme-card tc-light">☀<br>浅色</div>
          <div class="theme-card tc-dark">☾<br>深色</div>
        </div>
      </div>
      <div class="set-title">会话页</div>
      <div class="set-group glass">
        <div class="set-row"><div class="lbl">状态栏跟随远程页面</div><div class="set-toggle on"><i></i></div></div>
      </div>
      <div class="set-title">数据</div>
      <div class="set-group glass">
        <div class="set-row"><div class="lbl danger">清除所有连接</div><div class="go">›</div></div>
      </div>
      <div class="set-title">关于</div>
      <div class="set-group glass">
        <div class="set-row"><div class="lbl">版本</div><div class="val">1.3.0 (4)</div></div>
      </div>
    </div>
    <div class="glass-tab glass">
      <div class="tab-item">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:21px;height:21px"><path d="M13 2 4 14h6l-1 8 9-12h-6l1-8z"/></svg>连接
      </div>
      <div class="tab-item active tab-accent">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" style="width:21px;height:21px"><circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 0-.1-1.2l2-1.6-2-3.4-2.4 1a7 7 0 0 0-2-1.2L14 3h-4l-.5 2.6a7 7 0 0 0-2 1.2l-2.4-1-2 3.4 2 1.6A7 7 0 0 0 5 12c0 .4 0 .8.1 1.2l-2 1.6 2 3.4 2.4-1a7 7 0 0 0 2 1.2L10 21h4l.5-2.6a7 7 0 0 0 2-1.2l2.4 1 2-3.4-2-1.6c.1-.4.1-.8.1-1.2z"/></svg>设置
      </div>
    </div>
    <div class="homebar" style="background:rgba(255,255,255,.9)"></div>
  </div></div>
  <h2>设置页 · 黑主题态</h2>
  <div class="tip">主题三选一卡片：<b>跟随系统 / 浅色 / 深色</b>，选中琥珀描边。会话页状态栏仍智能跟随远程页面（可关）。清除连接/版本号顺手做了。</div>
</div>`;
fs.writeFileSync(p, h + settingsPhone);
console.log('设置页已追加');
