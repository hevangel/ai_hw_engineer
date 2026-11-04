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
  if (state.plots === 0) {
    ctx.fillStyle = '#0b0f0d';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
  for (const [x, y, intensity] of plots) {
    const px = (x / 1023) * (canvas.width - 8) + 4;
    const py = canvas.height - ((y / 1023) * (canvas.height - 8) + 4);
    ctx.fillStyle = `rgba(140, 255, 180, ${0.35 + Math.min(intensity, 7) / 10})`;
    ctx.fillRect(px, py, 2.2, 2.2);
  }
  if (plots.length) state.plots += plots.length;
  el('point-count').textContent = `${state.plots} points`;
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
    state.tty += stateData.tty;
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
  await api('/api/tape?file=work/demo.hex');
  state.plots = 0;
  state.tty = '';
  el('terminal').textContent = '';
  await command('RESET');
  await command(`LOAD ${'work/demo.hex'}`);
  await command('RESET');
  setRunning(true);
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
poll();
setInterval(() => { if (!state.running) poll(); }, 1000);
