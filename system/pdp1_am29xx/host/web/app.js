// PDP-1 Am29xx front panel.
//
// The panel is a thin client over /api/state and /api/command. It never
// interprets the guest instruction set: the RTL machine is the only source of
// architectural state, and display points come from the Type 30 IOT strobes.

const state = {
  tw: 0,
  ss: 0,
  running: false,
  timer: null,
  plots: 0,
  tty: '',
};

const el = (id) => document.getElementById(id);
const oct = (value, width) => value.toString(8).padStart(width, '0');

async function api(path) {
  const reply = await fetch(path);
  if (!reply.ok) throw new Error(`HTTP ${reply.status}`);
  return reply.json();
}

async function command(text) {
  return api(`/api/command?c=${encodeURIComponent(text)}`);
}

function buildBits(container, count, value, onToggle) {
  container.textContent = '';
  for (let bit = count - 1; bit >= 0; bit--) {
    const cell = document.createElement('div');
    cell.className = 'bit' + ((value >> bit) & 1 ? ' on' : '');
    cell.title = `bit ${bit}`;
    cell.addEventListener('click', () => onToggle(bit));
    container.appendChild(cell);
  }
}

function renderSwitches() {
  buildBits(el('tw-bits'), 18, state.tw, (bit) => {
    state.tw ^= 1 << bit;
    renderSwitches();
    command(`TW ${state.tw.toString(8)}`);
  });
  buildBits(el('ss-bits'), 6, state.ss, (bit) => {
    state.ss ^= 1 << bit;
    renderSwitches();
    command(`SS ${state.ss.toString(8)}`);
  });
  el('tw-value').textContent = oct(state.tw, 6);
  el('ss-value').textContent = oct(state.ss, 2);
}

function drawPlots(plots) {
  const canvas = el('crt');
  const ctx = canvas.getContext('2d');
  // The server keeps the full display history, so the canvas is repainted
  // from scratch; the point count is the history length, not a delta.
  ctx.fillStyle = '#0b0f0d';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  state.plots = plots.length;
  for (const [x, y, intensity] of plots) {
    const px = (x / 1023) * (canvas.width - 8) + 4;
    const py = canvas.height - ((y / 1023) * (canvas.height - 8) + 4);
    ctx.fillStyle = `rgba(140, 255, 180, ${0.35 + Math.min(intensity, 7) / 10})`;
    ctx.fillRect(px, py, 2.2, 2.2);
  }
  el('point-count').textContent = `${state.plots} points`;
}

// PDP-1 concise typewriter codes (F-16 table) to readable text. Codes the
// table does not cover are shown as <octal> so nothing is silently dropped.
const TTY = {
  0o77: '\n', 0o40: ' ', 0o54: '+', 0o57: '(', 0o55: ')', 0o73: 'x',
  0o61: 'a', 0o62: 'b', 0o63: 'c', 0o64: 'd', 0o65: 'e', 0o66: 'f',
  0o67: 'g', 0o70: 'h', 0o71: 'i', 0o41: 'j', 0o42: 'k', 0o43: 'l',
  0o44: 'm', 0o45: 'n', 0o46: 'o', 0o47: 'p', 0o50: 'q', 0o51: 'r',
  0o22: 's', 0o23: 't', 0o24: 'u', 0o25: 'v', 0o26: 'w', 0o27: 'x',
  0o30: 'y', 0o31: 'z', 0o01: '1', 0o02: '2', 0o03: '3', 0o04: '4',
  0o05: '5', 0o06: '6', 0o07: '7', 0o10: '8', 0o11: '9', 0o00: '0',
};

function decodeTty(codes) {
  let out = '';
  for (const raw of codes) {
    // The harness sends numeric PDP-1 concise codes; accept strings too so a
    // stale server cannot break the panel.
    const code = (typeof raw === 'number' ? raw : raw.charCodeAt(0)) & 0x3f;
    out += TTY[code] !== undefined ? TTY[code] : '<' + code.toString(8) + '>';
  }
  return out;
}

function update(stateData) {
  el('pc').textContent = oct(stateData.pc, 4);
  el('ma').textContent = oct(stateData.ma, 4);
  el('ac').textContent = oct(stateData.ac, 6);
  el('io').textContent = oct(stateData.io, 6);
  el('ir').textContent = oct(stateData.ir, 6);
  el('mb').textContent = oct(stateData.mb, 6);
  el('ov').textContent = stateData.ov ? '1' : '0';
  el('flags').textContent = oct(stateData.flags, 2);
  el('cycle-text').textContent = `${stateData.coreCycles * 5} µs · ${stateData.microcycles} microcycles`;
  const halted = !!stateData.halted;
  el('run-lamp').classList.toggle('on', state.running && !halted);
  el('status-text').textContent = halted ? 'halted' : (state.running ? 'running' : 'stopped');
  drawPlots(stateData.plots || []);
  if (stateData.tty) {
    state.tty = decodeTty(stateData.tty);
    if (state.tty.length > 4000) state.tty = state.tty.slice(-2000);
    el('terminal').textContent = state.tty;
    el('terminal').scrollTop = 1e9;
  }
}

async function poll() {
  try {
    update(await api('/api/state'));
  } catch (err) {
    el('status-text').textContent = `error: ${err.message}`;
  }
}

async function runBatch() {
  if (!state.running) return;
  try {
    const reply = await command('RUN 4000');
    if (reply.halted) {
      state.running = false;
      el('run').classList.remove('active');
    }
    await poll();
  } catch (err) {
    state.running = false;
    el('status-text').textContent = `error: ${err.message}`;
  }
  if (state.running) state.timer = setTimeout(runBatch, 30);
}

function setRunning(on) {
  state.running = on;
  el('run').classList.toggle('active', on);
  clearTimeout(state.timer);
  if (on) runBatch(); else poll();
}

el('run').addEventListener('click', () => setRunning(!state.running));
el('step').addEventListener('click', async () => { setRunning(false); await command('STEP 1'); await poll(); });
el('reset').addEventListener('click', async () => { setRunning(false); state.plots = 0; state.tty = ''; el('terminal').textContent = ''; await command('RESET'); await poll(); });
el('resume').addEventListener('click', async () => { await command('RESUME'); await poll(); });
el('clear-crt').addEventListener('click', () => { state.plots = 0; drawPlots([]); });
el('demo').addEventListener('click', async () => {
  setRunning(false);
  state.plots = 0;
  state.tty = '';
  el('terminal').textContent = '';
  try {
    await command('RESET');
    await command('LOAD work/demo.hex');
    await command('RESET');
    setRunning(true);
  } catch (err) {
    el('status-text').textContent = `demo error: ${err.message}`;
  }
});
el('send-key').addEventListener('click', async () => {
  const value = parseInt(el('key-input').value || '0', 8);
  await command(`KEY ${value.toString(16)}`);
  el('key-input').value = '';
});
el('capture').addEventListener('click', async () => {
  el('wave-note').textContent = 'capturing…';
  await command('WAVE 4000');
  el('wave-wrap').classList.remove('hidden');
  el('wave').src = '/surfer/?load=/waveform.fst';
  el('wave-note').textContent = 'Surfer loaded 4000 microcycles from /waveform.fst.';
});

renderSwitches();

// The server embeds the current machine state in the page, so the first paint
// (and any headless capture) shows a populated panel before polling starts.
const bootstrap = JSON.parse(el('bootstrap').textContent || '{}');
if (Object.keys(bootstrap).length) update(bootstrap);

// ?demo=1 loads and runs the built-in demonstration, which is what the
// committed screenshot shows.
if (new URLSearchParams(location.search).get('demo') === '1') {
  el('demo').click();
}

poll();
setInterval(() => { if (!state.running) poll(); }, 1000);
