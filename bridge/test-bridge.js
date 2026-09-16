#!/usr/bin/env node
/**
 * bridge 本地自检（零依赖）：起一个真 bridge 子进程，
 * 用手写 WS 客户端跑通：握手→token错→token对→welcome→send→output→exit。
 * 用法: node bridge/test-bridge.js   （需要 PATH 里有 node；zcode 不存在也能测错误路径）
 */
'use strict';
const { spawn } = require('child_process');
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');

const ROOT = path.join(__dirname);
const WORKDIR = fs.mkdtempSync(path.join(os.tmpdir(), 'zcode-bridge-test-'));
let passed = 0, failed = 0;
const check = (name, cond) => {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.error(`  ✗ ${name}`); }
};

// --- 手写最小 WS 客户端 ---
function wsConnect(port, tlsMode) {
  return new Promise((resolve, reject) => {
    const key = crypto.randomBytes(16).toString('base64');
    const req = http.request({
      host: '127.0.0.1', port,
      headers: {
        Connection: 'Upgrade', Upgrade: 'websocket',
        'Sec-WebSocket-Key': key, 'Sec-WebSocket-Version': '13',
      },
    });
    req.on('upgrade', (res, socket) => {
      const expect = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
      if (res.headers['sec-websocket-accept'] !== expect) return reject(new Error('accept 不匹配'));
      resolve(socket);
    });
    req.on('error', reject);
    req.end();
  });
}
function wsSendFrame(socket, opcode, payload) {
  const mask = crypto.randomBytes(4);
  const masked = Buffer.from(payload);
  for (let i = 0; i < masked.length; i++) masked[i] ^= mask[i & 3];
  let header;
  if (payload.length < 126) header = Buffer.from([0x80 | opcode, 0x80 | payload.length]);
  else { header = Buffer.alloc(4); header[0] = 0x80 | opcode; header[1] = 0x80 | 126; header.writeUInt16BE(payload.length, 2); }
  socket.write(Buffer.concat([header, mask, masked]));
}
function wsCollect(socket, predicate, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    let buf = Buffer.alloc(0);
    const timer = setTimeout(() => { socket.removeListener('data', onData); reject(new Error('等待消息超时')); }, timeoutMs);
    function onData(chunk) {
      buf = Buffer.concat([buf, chunk]);
      // 只处理单帧场景（测试消息都很小）
      const b0 = buf[0], b1 = buf[1];
      if (b0 === undefined) return;
      const opcode = b0 & 0x0f;
      let len = b1 & 0x7f, off = 2;
      if (len === 126) { len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { len = Number(buf.readBigUInt64BE(2)); off = 10; }
      if (buf.length < off + len) return;
      clearTimeout(timer);
      socket.removeListener('data', onData);
      const payload = buf.subarray(off, off + len);
      if (opcode === 0x8) return resolve({ opcode, close: true });
      try { resolve({ opcode, close: false, msg: JSON.parse(payload.toString('utf8')) }); }
      catch (e) { reject(e); }
    }
    socket.on('data', onData);
  });
}

async function main() {
  console.log('== bridge 自检 ==');
  // 1. 起服务
  const port = 18787;
  const proc = spawn(process.execPath, [path.join(ROOT, 'bridge.js'), '--port', String(port), '--host', '127.0.0.1', '--no-qr'], { cwd: WORKDIR });
  await new Promise((res, rej) => {
    proc.stdout.on('data', d => { if (String(d).includes('已启动')) res(); });
    proc.stderr.on('data', d => console.error('[bridge]', String(d).trim()));
    proc.on('exit', c => rej(new Error(`bridge 提前退出(${c})`)));
    setTimeout(() => rej(new Error('启动超时')), 5000);
  });
  console.log('  ✓ bridge 启动');

  const tokenFile = path.join(WORKDIR, '.zcode-bridge-token');
  check('token 文件已生成', fs.existsSync(tokenFile));
  const TOKEN = fs.readFileSync(tokenFile, 'utf8').trim();
  check('token 是 64 hex', /^[0-9a-f]{64}$/.test(TOKEN));

  // 2. token 错误 → error + 1008 close
  {
    const s = await wsConnect(port);
    wsSendFrame(s, 0x1, Buffer.from(JSON.stringify({ type: 'hello', token: 'f'.repeat(64) })));
    const err = await wsCollect(s, () => true);
    check('错误 token → error 消息', err.msg && err.msg.type === 'error');
    const close = await wsCollect(s, () => true, 3000).catch(() => ({ close: false }));
    check('错误 token → 服务端关闭', close.close === true);
    s.destroy();
  }

  // 3. 未认证 send → 拒绝
  {
    const s = await wsConnect(port);
    wsSendFrame(s, 0x1, Buffer.from(JSON.stringify({ type: 'send', text: 'hi' })));
    const err = await wsCollect(s, () => true);
    check('未认证 send 被拒', err.msg && /未认证/.test(err.msg.message || ''));
    s.destroy();
  }

  // 4. 正确 token → welcome；send → zcode 不存在时收到 error（本机无 zcode.cmd 的容错路径）
  {
    const s = await wsConnect(port);
    wsSendFrame(s, 0x1, Buffer.from(JSON.stringify({ type: 'hello', token: TOKEN })));
    const welcome = await wsCollect(s, () => true);
    check('正确 token → welcome', welcome.msg && welcome.msg.type === 'welcome');

    wsSendFrame(s, 0x1, Buffer.from(JSON.stringify({ type: 'send', text: 'echo hi' })));
    const next = await wsCollect(s, () => true, 6000);
    const isErr = next.msg && next.msg.type === 'error' && /无法启动 zcode/.test(next.msg.message || '');
    const isOutput = next.msg && (next.msg.type === 'output' || next.msg.type === 'exit');
    check('send 后有响应(error=无zcode / output/exit=有zcode)', isErr || isOutput);
    if (isOutput) {
      // 有真 zcode：再等 exit 或更多 output 都算过
      const more = await wsCollect(s, () => true, 8000).catch(() => null);
      check('zcode 会话有输出/退出事件', more === null || more.close || ['output', 'exit', 'error'].includes(more.msg && more.msg.type));
    }
    s.destroy();
  }

  // 5. ping/pong
  {
    const s = await wsConnect(port);
    wsSendFrame(s, 0x1, Buffer.from(JSON.stringify({ type: 'hello', token: TOKEN })));
    await wsCollect(s, m => true); // welcome
    wsSendFrame(s, 0x1, Buffer.from(JSON.stringify({ type: 'ping' })));
    const pong = await wsCollect(s, () => true);
    check('ping → pong', pong.msg && pong.msg.type === 'pong');
    s.destroy();
  }

  proc.kill();
  await new Promise(res => { proc.on('exit', res); setTimeout(res, 2000); }); // 等句柄释放再删临时目录
  console.log(`\n结果: ${passed} 通过, ${failed} 失败`);
  fs.rmSync(WORKDIR, { recursive: true, force: true });
  process.exit(failed ? 1 : 0);
}

main().catch(e => { console.error('自检失败:', e.message); process.exit(1); });
