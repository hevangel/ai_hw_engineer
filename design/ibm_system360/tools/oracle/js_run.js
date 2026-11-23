// Run one program image on an independent S/360 emulator and dump state.
//
// Usage: node js_run.js <prog.hex> <words> <steps> <out.txt>
// The emulator is the JavaScript Model 30 from
// https://github.com/luiscunhacsc/s360-model30-v01, kept in the ignored work/
// tree. Its commit, URL and licence status are recorded in spec/sources.md.
'use strict';

const fs = require('fs');
const path = require('path');

const root = process.env.ORACLE_ROOT;
if (!root) {
  console.error('ORACLE_ROOT is not set');
  process.exit(2);
}
require(path.join(root, 'src/ebcdic.js'));
require(path.join(root, 'src/core.js'));

const [progPath, wordsArg, stepsArg, outPath] = process.argv.slice(2);
const words = parseInt(wordsArg, 10);
const steps = parseInt(stepsArg, 10);

const hexWords = fs.readFileSync(progPath, 'utf8').trim().split(/\s+/).filter(Boolean);

const cpu = new S360.CPU(65536);
cpu.manual = true;
cpu.resetPending = false;
cpu.psw = { sysMask: 0, key: 0, A: 0, M: 0, W: 0, P: 0, intCode: 0, ilc: 0, cc: 0, progMask: 0, ia: 0x100 };

for (let i = 0; i < words; i++) {
  const w = parseInt(hexWords[i] || '0', 16) >>> 0;
  const a = 4 * i;
  cpu.mem[a] = (w >>> 24) & 0xff;
  cpu.mem[a + 1] = (w >>> 16) & 0xff;
  cpu.mem[a + 2] = (w >>> 8) & 0xff;
  cpu.mem[a + 3] = w & 0xff;
}

let retired = 0;
while (retired < steps) {
  cpu.step();
  retired++;
}

const p = cpu.psw;
const word0 = (((p.sysMask & 0xff) << 24) | ((p.key & 0xf) << 20) | ((p.A & 1) << 19) |
               ((p.M & 1) << 18) | ((p.W & 1) << 17) | ((p.P & 1) << 16) | (p.intCode & 0xffff)) >>> 0;
const word1 = (((p.ilc & 3) << 30) | ((p.cc & 3) << 28) | ((p.progMask & 0xf) << 24) | (p.ia & 0xffffff)) >>> 0;

const h8 = (v) => (v >>> 0).toString(16).toUpperCase().padStart(8, '0');
const lines = [];
lines.push('psw ' + h8(word0) + h8(word1));
for (let i = 0; i < 16; i++) {
  lines.push('gpr ' + i + ' ' + h8(cpu.gpr[i]));
}
const dumpWord = (a) => ((cpu.mem[a] << 24) | (cpu.mem[a + 1] << 16) | (cpu.mem[a + 2] << 8) | cpu.mem[a + 3]) >>> 0;
for (const a of [0x028, 0x02c]) {
  lines.push('mem ' + a.toString(16).toUpperCase().padStart(6, '0') + ' ' + h8(dumpWord(a)));
}
for (let a = 0x200; a < 0x240; a += 4) {
  lines.push('mem ' + a.toString(16).toUpperCase().padStart(6, '0') + ' ' + h8(dumpWord(a)));
}
lines.push('int 0 ' + (p.intCode >>> 0));
fs.writeFileSync(outPath, lines.join('\n') + '\n');
