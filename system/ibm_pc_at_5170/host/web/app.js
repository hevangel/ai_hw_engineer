// Front panel of the RTL IBM PC AT 5170: monitor, controls, keyboard and
// the batch-run viewer. The waveform panel is waveform.js.

// Browser KeyboardEvent.code -> IBM AT 84-key keyboard, scan code set 2
// make code (Technical Reference, March 1984, printed page 4-12). The AT
// keyboard has no separate cursor, editing or F11/F12 keys: cursor and
// editing keys map to the numeric keypad keys that carry them, right Ctrl
// and Alt map to the only Ctrl and Alt, and keys without an AT key are not
// sent. Backslash is the key left of Backspace; F7 is 83h, SysRq 84h.
export const SET2 = {
  Escape:0x76, Backquote:0x0e, Digit1:0x16, Digit2:0x1e, Digit3:0x26, Digit4:0x25, Digit5:0x2e,
  Digit6:0x36, Digit7:0x3d, Digit8:0x3e, Digit9:0x46, Digit0:0x45, Minus:0x4e, Equal:0x55,
  Backslash:0x5d, Backspace:0x66, Tab:0x0d, KeyQ:0x15, KeyW:0x1d, KeyE:0x24, KeyR:0x2d, KeyT:0x2c,
  KeyY:0x35, KeyU:0x3c, KeyI:0x43, KeyO:0x44, KeyP:0x4d, BracketLeft:0x54, BracketRight:0x5b,
  Enter:0x5a, ControlLeft:0x14, ControlRight:0x14, KeyA:0x1c, KeyS:0x1b, KeyD:0x23, KeyF:0x2b,
  KeyG:0x34, KeyH:0x33, KeyJ:0x3b, KeyK:0x42, KeyL:0x4b, Semicolon:0x4c, Quote:0x52,
  ShiftLeft:0x12, KeyZ:0x1a, KeyX:0x22, KeyC:0x21, KeyV:0x2a, KeyB:0x32, KeyN:0x31, KeyM:0x3a,
  Comma:0x41, Period:0x49, Slash:0x4a, ShiftRight:0x59, AltLeft:0x11, AltRight:0x11, Space:0x29,
  CapsLock:0x58, F1:0x05, F2:0x06, F3:0x04, F4:0x0c, F5:0x03, F6:0x0b, F7:0x83, F8:0x0a, F9:0x01,
  F10:0x09, NumLock:0x77, ScrollLock:0x7e, PrintScreen:0x84,
  Numpad7:0x6c, Numpad8:0x75, Numpad9:0x7d, NumpadSubtract:0x7b, Numpad4:0x6b, Numpad5:0x73,
  Numpad6:0x74, NumpadAdd:0x79, Numpad1:0x69, Numpad2:0x72, Numpad3:0x7a, Numpad0:0x70,
  NumpadDecimal:0x71, NumpadMultiply:0x7c, NumpadEnter:0x5a, NumpadDivide:0x4a,
  Home:0x6c, ArrowUp:0x75, PageUp:0x7d, ArrowLeft:0x6b, ArrowRight:0x74, End:0x69,
  ArrowDown:0x72, PageDown:0x7a, Insert:0x70, Delete:0x71,
};

const $ = id => document.getElementById(id);
const canvas = $('display'), ctx = canvas.getContext('2d');
let state = null, shownFrame = -1, frameBusy = false;
const held = new Set();

export function currentState() { return state; }

export async function control(action, extra = {}) {
  const r = await fetch('/api/control', {method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({action, ...extra})});
  const data = await r.json();
  if (!r.ok) { showError(data.error || r.statusText); return null; }
  showError('');
  state = data; render();
  return data;
}

function showError(text) { $('error').hidden = !text; $('error').textContent = text; }
const fmt = n => Number(n).toLocaleString('en-US');

function render() {
  if (!state) return;
  const on = state.powered;
  $('power').textContent = on ? 'Power off' : 'Power on';
  $('run').disabled = !on || state.running || !!state.stopped;
  $('pause').disabled = !on || !state.running;
  $('reset').disabled = !on;
  $('monitor-led').classList.toggle('on', on);
  $('config').textContent = `80286 · ${state.extKB ? fmt(640 + state.extKB) + ' KB (640 KB + ' + fmt(state.extKB) + ' KB from 1 MB)' : '640 KB'}`;
  $('post').textContent = state.post + 'h';
  $('csip').textContent = `${state.cs}:${state.ip}`;
  $('clocks').textContent = fmt(state.clocks);
  $('instructions').textContent = fmt(state.instructions);
  $('frames').textContent = fmt(state.frames);
  $('speed').textContent = state.clocksPerSecond ? fmt(state.clocksPerSecond) + ' clk/s' : '--';
  $('realtime').textContent = state.clocksPerSecond ? (state.realTimeFraction * 100).toFixed(2) + ' %' : '--';
  $('simtime').textContent = state.simSeconds.toFixed(3) + ' s';
  $('machine-state').textContent = !on ? 'Power off.' : state.stopped ? `Stopped: ${state.stopped}` :
    state.running ? 'Running.' + (state.halted ? ' Processor halted.' : '') : 'Paused.';
  const k = state.keyboard;
  $('led-scroll').classList.toggle('on', on && !!(k.leds & 1));
  $('led-num').classList.toggle('on', on && !!(k.leds & 2));
  $('led-caps').classList.toggle('on', on && !!(k.leds & 4));
  $('kbd-state').textContent = `${k.state}${k.scanning ? '' : ', not scanning'} · sent ${k.sent} · received ${k.received}` +
    (k.lastReceived >= 0 ? ` (last command ${k.lastReceived.toString(16).toUpperCase()}h)` : '') +
    (k.pendingKeys ? ` · ${k.pendingKeys} key events waiting` : '');
  $('overlay').hidden = on && state.frames > 0;
  $('overlay').textContent = on ? 'NO SIGNAL YET' : 'POWER OFF';
  if (on && state.frames !== shownFrame) loadFrame(state.frames);
}

async function loadFrame(n) {
  if (frameBusy) return;
  frameBusy = true;
  try {
    const r = await fetch('/api/frame.png?n=' + n);
    if (r.ok) {
      const bmp = await createImageBitmap(await r.blob());
      if (canvas.width !== bmp.width || canvas.height !== bmp.height) { canvas.width = bmp.width; canvas.height = bmp.height; }
      ctx.drawImage(bmp, 0, 0);
      shownFrame = n;
    }
  } finally { frameBusy = false; }
}

async function poll() {
  try {
    const r = await fetch('/api/state');
    if (r.ok) { state = await r.json(); render(); }
  } catch (e) { showError('Server not reachable'); }
}

$('power').onclick = () => control('POWER', {on: !state?.powered});
$('run').onclick = () => control('RUN');
$('pause').onclick = () => control('PAUSE');
$('reset').onclick = () => control('RESET');
for (const b of document.querySelectorAll('[data-keys]'))
  b.onclick = () => { control('TYPE', {keys: b.dataset.keys}); $('screen').focus(); };

// Physical keyboard: only while the display has focus. Browser auto-repeat
// is ignored; the keyboard model makes its own typematic repeats.
const screen = $('screen');
screen.addEventListener('click', () => screen.focus());
screen.addEventListener('keydown', e => {
  const code = SET2[e.code];
  if (code === undefined) return;
  e.preventDefault();
  if (e.repeat || held.has(e.code)) return;
  held.add(e.code);
  control('KEY', {events: [{code, make: true}]});
});
screen.addEventListener('keyup', e => {
  const code = SET2[e.code];
  if (code === undefined) return;
  e.preventDefault();
  if (!held.delete(e.code)) return;
  control('KEY', {events: [{code, make: false}]});
});
// Focus lost: release every key still held, as a real keyboard would see.
screen.addEventListener('blur', () => {
  const events = [...held].map(c => ({code: SET2[c], make: false}));
  held.clear();
  if (events.length) control('KEY', {events});
});

// Batch run viewer: live status and replay of the saved frames.
let batch = null, batchIndex = -1, live = true, playing = null;
async function pollBatch() {
  const r = await fetch('/api/batch');
  if (!r.ok) return;
  batch = await r.json();
  if (!batch.batch) return;
  $('batch_panel').hidden = false;
  $('batch_dir').textContent = batch.dir;
  const s = batch.status;
  const slider = $('batch_slider');
  slider.max = Math.max(0, batch.frames.length - 1);
  if (live) { batchIndex = batch.frames.length - 1; slider.value = slider.max; }
  if (s) {
    const st = s.state;
    $('batch_status').textContent = `${s.done ? 'Finished' : 'Running'} · ${fmt(st.clocks)} of ${fmt(s.targetClocks)} clocks · ` +
      `POST ${st.post}h · ${st.cs}:${st.ip} · ${fmt(st.instructions)} instructions · ${fmt(st.clocksPerSecond)} clk/s · ` +
      `${(s.wallSeconds / 3600).toFixed(2)} h wall · ${s.savedFrames} saved frames` + (st.stopped ? ` · stopped: ${st.stopped}` : '') +
      (s.scriptLog.length ? ` · script: ${s.scriptLog[s.scriptLog.length - 1]}` : '');
    if (live) $('batch_screen').textContent = s.screen.join('\n');
  }
  showBatchFrame();
}
function showBatchFrame() {
  if (!batch?.frames.length) return;
  const f = live ? null : batch.frames[batchIndex];
  const src = f ? `/api/batch/frames/${f.file}` : `/api/batch/latest.png?t=${batch.status?.state.clocks}`;
  if ($('batch_image').dataset.src !== src) { $('batch_image').src = src; $('batch_image').dataset.src = src; }
  $('batch_live').disabled = live;
  if (f) $('batch_screen').textContent = `Saved frame ${batchIndex + 1} of ${batch.frames.length}, at clock ${fmt(f.clock)}`;
}
function seek(i) { live = false; batchIndex = Math.max(0, Math.min(i, batch.frames.length - 1)); $('batch_slider').value = batchIndex; showBatchFrame(); }
$('batch_slider').oninput = e => seek(Number(e.target.value));
$('batch_prev').onclick = () => seek(batchIndex - 1);
$('batch_next').onclick = () => seek(batchIndex + 1);
$('batch_live').onclick = () => { live = true; pollBatch(); };
$('batch_play').onclick = () => {
  if (playing) { clearInterval(playing); playing = null; $('batch_play').textContent = 'Play'; return; }
  $('batch_play').textContent = 'Stop';
  if (batchIndex >= batch.frames.length - 1) seek(0);
  playing = setInterval(() => { if (batchIndex >= batch.frames.length - 1) $('batch_play').click(); else seek(batchIndex + 1); }, 400);
};

setInterval(poll, 300);
setInterval(pollBatch, 2000);
poll(); pollBatch();
