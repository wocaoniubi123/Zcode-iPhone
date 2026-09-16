#!/usr/bin/env node
/**
 * zcode-ios-shell / bridge.js
 * PC 端桥接：局域网 WebSocket 服务 ↔ 本机 ZCode CLI。
 *
 * 零第三方依赖（Node 18+：ws 用 RFC6455 手写实现，TLS 用 node:tls）。
 *
 * 用法：
 *   node bridge.js [--port 8787] [--host 0.0.0.0] [--tls] [--cert cert.pem] [--key key.pem] [--no-qr]
 *
 * 首次运行自动生成 token，写入 <cwd>/.zcode-bridge-token，并用终端 QR 码
 * 打印 zcode://<LAN-IP>:<port>?token=...&tls=1 供 iOS 壳扫描。
 *
 * 协议（JSON 消息，一行一帧）：
 *   客户端 → 服务端：{"type":"hello","token":"..."}
 *                    {"type":"send","text":"..."}
 *                    {"type":"input","text":"..."}     // 等价 send
 *                    {"type":"ping"}
 *   服务端 → 客户端：{"type":"welcome","version":"..."}
 *                    {"type":"output","text":"..."}    // zcode 增量输出
 *                    {"type":"exit","code":0}
 *                    {"type":"error","message":"..."}
 *                    {"type":"pong"}
 */
'use strict';

const http = require('http');
const https = require('https');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

// ---------------------------------------------------------------------------
// 参数解析
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
function argOf(name, def) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}
const hasFlag = (name) => args.includes(name);

const PORT = parseInt(argOf('--port', '8787'), 10);
const HOST = argOf('--host', '0.0.0.0');
const TLS_ENABLED = hasFlag('--tls');
const CERT_FILE = argOf('--cert', 'cert.pem');
const KEY_FILE = argOf('--key', 'key.pem');
const SHOW_QR = !hasFlag('--no-qr');

if (!Number.isInteger(PORT) || PORT <= 0 || PORT > 65535) {
  console.error(`[bridge] 非法端口: ${argOf('--port', '8787')}`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// token：持久化到 .zcode-bridge-token（0600，Windows 忽略 mode 失败）
// ---------------------------------------------------------------------------
const TOKEN_FILE = path.join(process.cwd(), '.zcode-bridge-token');
function loadOrCreateToken() {
  try {
    const t = fs.readFileSync(TOKEN_FILE, 'utf8').trim();
    if (/^[0-9a-f]{64}$/.test(t)) return t;
  } catch (_) { /* 不存在则生成 */ }
  const t = crypto.randomBytes(32).toString('hex');
  try {
    fs.writeFileSync(TOKEN_FILE, t + '\n', { mode: 0o600 });
  } catch (_) {
    fs.writeFileSync(TOKEN_FILE, t + '\n'); // Windows 上 chmod 语义不同，忽略
  }
  return t;
}
const TOKEN = loadOrCreateToken();

// ---------------------------------------------------------------------------
// 可选 TLS
// ---------------------------------------------------------------------------
let tlsOptions = null;
if (TLS_ENABLED) {
  try {
    tlsOptions = {
      key: fs.readFileSync(KEY_FILE),
      cert: fs.readFileSync(CERT_FILE),
    };
  } catch (e) {
    console.error(`[bridge] 读取证书失败(${KEY_FILE}/${CERT_FILE}): ${e.message}`);
    console.error('[bridge] 可用 openssl 生成自签证书:');
    console.error('  openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 -subj "/CN=zcode-bridge"');
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// zcode 进程管理：单会话，退出后允许重开。查找顺序 --zcode → PATH → 常见安装位置
// ---------------------------------------------------------------------------
const ZCODE_BIN = argOf('--zcode', process.platform === 'win32' ? 'zcode.cmd' : 'zcode');

function resolveZcode() {
  const candidates = [ZCODE_BIN];
  if (process.platform === 'win32') {
    candidates.push(path.join(os.homedir(), 'AppData', 'Local', 'Programs', 'ZCode', 'ZCode.exe'));
  }
  for (const c of candidates) {
    if (!c) continue;
    try {
      fs.accessSync(c, fs.constants.X_OK);
      return c;
    } catch (_) { /* next */ }
  }
  return ZCODE_BIN; // 兜底交给 spawn 自己找 PATH
}

const zcodeBin = resolveZcode();

// ponytail: 单会话模型——一个 WS 客户端挂一个 zcode 进程，断开即杀。
// 多人并发再改会话池。
let child = null;
let childBuf = '';

function killChild() {
  if (!child) return;
  try { child.kill(); } catch (_) { try { child.kill('SIGKILL'); } catch (_) {} }
  child = null;
  childBuf = '';
}

function startZcode(ws) {
  killChild();
  childBuf = '';
  child = spawn(zcodeBin, [], {
    shell: process.platform === 'win32',
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, TERM: 'dumb', NO_COLOR: '1', FORCE_COLOR: '0' },
  });
  const feed = (chunk) => {
    childBuf += chunk.toString('utf8');
    // ponytail: 按行切割即可满足对话场景；二进制/无行尾输出缓冲到下次
    let idx;
    while ((idx = childBuf.indexOf('\n')) >= 0) {
      const line = childBuf.slice(0, idx);
      childBuf = childBuf.slice(idx + 1);
      wsSend(ws, { type: 'output', text: line + '\n' });
    }
    if (childBuf) wsSend(ws, { type: 'output', text: childBuf }); // 无行尾残余
  };
  child.stdout.on('data', feed);
  child.stderr.on('data', feed);
  child.on('close', (code) => {
    child = null;
    wsSend(ws, { type: 'exit', code: code ?? 0 });
  });
  child.on('error', (e) => {
    child = null;
    wsSend(ws, { type: 'error', message: `无法启动 zcode (${zcodeBin}): ${e.message}` });
  });
}

// ---------------------------------------------------------------------------
// 手写 WebSocket 服务端（RFC6455，够 bridge 用：文本帧、掩码、close、ping/pong）
// ---------------------------------------------------------------------------
const WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

function wsAccept(key) {
  return crypto.createHash('sha1').update(key + WS_GUID).digest('base64');
}

function encodeFrame(opcode, payload) {
  const len = payload.length;
  let header;
  if (len < 126) {
    header = Buffer.from([0x80 | opcode, len]);
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode; header[1] = 126; header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode; header[1] = 127; header.writeBigUInt64BE(BigInt(len), 2);
  }
  return Buffer.concat([header, payload]);
}

function decodeFrames(buffer, onMessage, onClose) {
  let frames = [];
  let off = 0;
  while (off + 2 <= buffer.length) {
    const b0 = buffer[off], b1 = buffer[off + 1];
    const masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f;
    let hdr = 2;
    if (len === 126) {
      if (off + 4 > buffer.length) break;
      len = buffer.readUInt16BE(off + 2); hdr = 4;
    } else if (len === 127) {
      if (off + 10 > buffer.length) break;
      const big = buffer.readBigUInt64BE(off + 2);
      if (big > BigInt(64 * 1024 * 1024)) { onClose && onClose(); return []; }
      len = Number(big); hdr = 10;
    }
    let mask = null;
    if (masked) {
      if (off + hdr + 4 > buffer.length) break;
      mask = buffer.subarray(off + hdr, off + hdr + 4);
      hdr += 4;
    }
    if (off + hdr + len > buffer.length) break; // 半帧，等下个 chunk
    let payload = buffer.subarray(off + hdr, off + hdr + len);
    if (mask) {
      payload = Buffer.from(payload); // copy 以便解掩码
      for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
    }
    frames.push({ opcode: b0 & 0x0f, fin: (b0 & 0x80) !== 0, payload });
    off += hdr + len;
  }
  onMessage(frames, off); // off = 已消费字节数
  return frames;
}

function wsSend(ws, obj) {
  if (!ws || ws.readyState !== 'open') return;
  ws.write(encodeFrame(0x1, Buffer.from(JSON.stringify(obj), 'utf8')));
}

function wsClose(ws, code = 1000) {
  try { ws.write(encodeFrame(0x8, Buffer.from([code >> 8, code & 0xff]))); } catch (_) {}
  try { ws.end(); } catch (_) {}
}

// ---------------------------------------------------------------------------
// HTTP(S) + WS 升级
// ---------------------------------------------------------------------------
const handler = (req, res) => {
  // ponytail: / 仅回一个极简状态页，够确认服务活着；不做完整 web UI
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('zcode bridge running\n');
};

const server = TLS_ENABLED
  ? https.createServer(tlsOptions, handler)
  : http.createServer(handler);

server.on('upgrade', (req, socket) => {
  const key = req.headers['sec-websocket-key'];
  if (!key) { socket.destroy(); return; }
  socket.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
    'Upgrade: websocket\r\n' +
    'Connection: Upgrade\r\n' +
    `Sec-WebSocket-Accept: ${wsAccept(key)}\r\n\r\n`
  );
  socket.setNoDelay(true);
  let acc = Buffer.alloc(0);
  let open = true;
  let authed = false;

  socket.on('data', (chunk) => {
    acc = Buffer.concat([acc, chunk]);
    decodeFrames(acc, (frames, consumed) => {
      acc = acc.subarray(consumed);
      for (const f of frames) {
        if (f.opcode === 0x8) { // close
          open = false;
          wsClose(socket);
          killChild();
          return;
        }
        if (f.opcode === 0x9) { // ping → pong
          socket.write(encodeFrame(0xA, f.payload));
          continue;
        }
        if (f.opcode !== 0x1) continue; // 只处理文本帧
        let msg;
        try { msg = JSON.parse(f.payload.toString('utf8')); }
        catch (_) { wsSend(socket, { type: 'error', message: 'bad json' }); continue; }

        if (msg.type === 'hello') {
          const ok = typeof msg.token === 'string' &&
            msg.token.length === TOKEN.length &&
            crypto.timingSafeEqual(Buffer.from(msg.token), Buffer.from(TOKEN));
          if (!ok) {
            wsSend(socket, { type: 'error', message: 'token 无效' });
            wsClose(socket, 1008);
            killChild();
            return;
          }
          authed = true;
          wsSend(socket, { type: 'welcome', version: '1' });
          continue;
        }
        if (!authed) {
          wsSend(socket, { type: 'error', message: '未认证，先发 hello' });
          wsClose(socket, 1008);
          return;
        }
        if (msg.type === 'send' || msg.type === 'input') {
          if (typeof msg.text !== 'string' || msg.text.length > 100000) {
            wsSend(socket, { type: 'error', message: 'text 字段非法' });
            continue;
          }
          if (!child) startZcode(socket);
          try { child.stdin.write(msg.text.endsWith('\n') ? msg.text : msg.text + '\n'); }
          catch (e) { wsSend(socket, { type: 'error', message: `写入 zcode 失败: ${e.message}` }); }
          continue;
        }
        if (msg.type === 'ping') { wsSend(socket, { type: 'pong' }); continue; }
      }
    }, () => { // 巨帧防护回调
      open = false;
      socket.destroy();
    });
  });

  socket.on('error', () => { open = false; killChild(); });
  socket.on('close', () => { if (open) { open = false; killChild(); } });
});

// ---------------------------------------------------------------------------
// LAN IP 探测 + 终端二维码
// ---------------------------------------------------------------------------
function lanIP() {
  const faces = os.networkInterfaces();
  for (const list of Object.values(faces)) {
    for (const it of list || []) {
      if (it.family === 'IPv4' && !it.internal) return it.address;
    }
  }
  return '127.0.0.1';
}

// ponytail: 终端 QR 用 qrcode-terminal 逻辑太重，直接打印 URL + 手动方案说明。
// 若需要真二维码：npm i -g qrcode-terminal 后 `qrcode-terminal "..."`。
function printBanner() {
  const scheme = TLS_ENABLED ? 'zcodes' : 'zcode';
  const url = `${scheme}://${lanIP()}:${PORT}?token=${TOKEN}${TLS_ENABLED ? '&tls=1' : ''}`;
  console.log('──────────────────────────────────────────────');
  console.log(' zcode bridge 已启动');
  console.log(` 地址: ${url}`);
  console.log(` token 文件: ${TOKEN_FILE}`);
  console.log(' iOS 壳扫码即可连接；未扫过码时也可手动输入地址。');
  console.log('──────────────────────────────────────────────');
}

server.listen(PORT, HOST, () => {
  printBanner();
});

server.on('error', (e) => {
  console.error(`[bridge] 监听失败: ${e.message}`);
  process.exit(1);
});

process.on('SIGINT', () => { killChild(); process.exit(0); });
process.on('SIGTERM', () => { killChild(); process.exit(0); });
