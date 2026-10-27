// SNES panel. All machine state comes from the RTL; the browser only
// expands BGR555 to RGB and plays the S-DSP's 32 kHz samples.
let captureVersion = 0;
let soundOn = false;
let audio = null;
let audioTime = 0;

const canvas = document.getElementById('screen');
const ctx = canvas.getContext('2d');
const img = ctx.createImageData(512, 224);

// SCREEN is 512 x 240 little-endian BGR555; row 0 is display line 1.
function renderScreen(b64) {
    const raw = atob(b64);
    for (let n = 0, p = 0; n < 512 * 224; ++n) {
        const v = raw.charCodeAt(2 * n) | (raw.charCodeAt(2 * n + 1) << 8);
        const r = v & 31, g = (v >> 5) & 31, b = (v >> 10) & 31;
        img.data[p++] = (r << 3) | (r >> 2);
        img.data[p++] = (g << 3) | (g >> 2);
        img.data[p++] = (b << 3) | (b >> 2);
        img.data[p++] = 255;
    }
    ctx.putImageData(img, 0, 0);
}

// ---- Audio: interleaved stereo int16 at the S-DSP's 32 kHz rate.
function playAudio(b64) {
    if (!soundOn || !b64) return;
    if (!audio) audio = new AudioContext();
    const raw = atob(b64);
    const count = raw.length >> 2;
    if (!count) return;
    const buffer = audio.createBuffer(2, count, 32000);
    for (let c = 0; c < 2; ++c) {
        const data = buffer.getChannelData(c);
        for (let n = 0; n < count; ++n) {
            const k = 4 * n + 2 * c;
            let v = raw.charCodeAt(k) | (raw.charCodeAt(k + 1) << 8);
            if (v & 0x8000) v -= 0x10000;
            data[n] = v / 32768;
        }
    }
    const source = audio.createBufferSource();
    source.buffer = buffer;
    source.connect(audio.destination);
    audioTime = Math.max(audioTime, audio.currentTime + 0.05);
    source.start(audioTime);
    audioTime += buffer.duration;
}

// ---- Controller 1: {R, L, X, A, Right, Left, Down, Up, Start, Select, Y, B}, 1 = pressed.
const KEYMAP = {
    'z': 0x001, 'a': 0x002, 'Shift': 0x004, 'Enter': 0x008,
    'ArrowUp': 0x010, 'ArrowDown': 0x020, 'ArrowLeft': 0x040, 'ArrowRight': 0x080,
    'x': 0x100, 's': 0x200, 'q': 0x400, 'w': 0x800,
};
const held = new Set();

async function post(body) {
    const response = await fetch('/api/control', {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
    });
    const data = await response.json();
    if (!data.error) applyState(data);
    return data;
}

function sendPad() {
    let value = 0;
    for (const name of held) value |= KEYMAP[name] || 0;
    post({action: 'PAD1', value});
}
canvas.addEventListener('keydown', event => {
    const name = event.key.length === 1 ? event.key.toLowerCase() : event.key;
    if (!(name in KEYMAP)) return;
    event.preventDefault();
    if (held.has(name)) return;
    held.add(name);
    sendPad();
});
canvas.addEventListener('keyup', event => {
    const name = event.key.length === 1 ? event.key.toLowerCase() : event.key;
    if (held.delete(name)) sendPad();
});
canvas.addEventListener('blur', () => { if (held.size) { held.clear(); sendPad(); } });

const hex = (v, w = 2) => v.toString(16).padStart(w, '0').toUpperCase();

function applyState(state) {
    if (state.error) return;
    if (state.captureVersion > captureVersion) captureVersion = state.captureVersion;
    if (state.screen) renderScreen(state.screen);
    playAudio(state.audio);
    const run = document.getElementById('state_run');
    run.textContent = state.running ? 'RUN' : 'STOP';
    run.className = 'state_chip' + (state.running ? ' active' : '');
    document.getElementById('state_region').textContent = state.region ? 'PAL' : 'NTSC';
    document.getElementById('state_overrun').hidden = !state.overrun;
    const flags = state.e ? ['N', 'V', '1', 'B', 'D', 'I', 'Z', 'C']
                          : ['N', 'V', 'M', 'X', 'D', 'I', 'Z', 'C'];
    const rows = [
        ['Cartridge', state.rom || '—'],
        ['PC', hex(state.pc, 6)], ['A', hex(state.a, 4)], ['X', hex(state.x, 4)],
        ['Y', hex(state.y, 4)], ['S', hex(state.s, 4)], ['D', hex(state.d, 4)],
        ['DBR', hex(state.dbr)],
        ['P', flags.map((n, k) => (state.p >> (7 - k)) & 1 ? n : '.').join(' ') +
              (state.e ? ' (emulation)' : ' (native)')],
        ['SPC700 PC', hex(state.smpPc, 4)],
        ['Raster', `line ${state.vcount}, clock ${state.hcount}`],
        ['Frames', state.frames], ['CPU cycles', state.cycles],
        ['SPC700 cycles', state.smpCycles],
        ['Controller 1', hex(state.pad1, 3)],
    ];
    document.getElementById('cpu_table').innerHTML =
        rows.map(([n, v]) => `<tr><th>${n}</th><td>${v}</td></tr>`).join('');
}

async function poll() {
    try {
        const response = await fetch('/api/state');
        const state = await response.json();
        if (!state.error) applyState(state);
    } catch (error) {
        /* backend restarting */
    }
    setTimeout(poll, 60);
}

async function loadRoms() {
    const response = await fetch('/api/roms');
    const data = await response.json();
    const select = document.getElementById('rom_select');
    select.innerHTML = data.roms.map(r => `<option>${r}</option>`).join('');
    if (data.current) select.value = data.current;
}

document.getElementById('btn_load').addEventListener('click', () =>
    post({action: 'LOAD', rom: document.getElementById('rom_select').value}));
document.getElementById('btn_run').addEventListener('click', () => post({action: 'RUNSW'}));
document.getElementById('btn_reset').addEventListener('click', () => post({action: 'RESET'}));
document.getElementById('btn_sound').addEventListener('click', event => {
    soundOn = !soundOn;
    event.target.textContent = soundOn ? 'Sound: on' : 'Sound: off';
    if (soundOn && !audio) audio = new AudioContext();
});

// ---- Waveform panel (same Surfer bridge as the other system panels).
const WAVE_SIGNALS = {
    cpu: ['clk', 'bus_ce', 'a_addr', 'cpu_fetch', 'cpu_pc', 'cpu_a', 'cpu_x', 'cpu_y',
          'cpu_s', 'cpu_d', 'cpu_p', 'cpu_dbr', 'cpu_e', 'vcount', 'hcount'],
    ppu: ['clk', 'vcount', 'hcount', 'line_start', 'vram_raddr', 'vram_rdata', 'vram_caddr',
          'vram_cwe_lo', 'vram_cwe_hi', 'vram_cwdata', 'pix_valid', 'pix_x', 'pix_y', 'pix_rgb'],
    apu: ['clk', 'apu_tick', 'smp_fetch', 'smp_pc', 'dsp.phase_o', 'dsp.ram_addr',
          'dsp.ram_we', 'sample_valid', 'sample_l', 'sample_r', 'dsp_overrun'],
};

function bindWaveform() {
    const frame = document.getElementById('surfer_frame');
    const capture = document.getElementById('waveform_capture');
    const refresh = document.getElementById('waveform_refresh');
    const download = document.getElementById('waveform_download');
    const status = document.getElementById('waveform_status');
    const preset = document.getElementById('waveform_signals');
    const prefix = 'TOP.snes.';

    const loadWaveform = () => {
        if (!captureVersion) return;
        const url = new URL('/surfer/', location.origin);
        url.searchParams.set('load_url', `${location.origin}/waveform.fst?capture=${captureVersion}`);
        url.hash = 'dev';
        frame.src = url.href;
    };

    frame.addEventListener('load', () => {
        if (!frame.src.includes('load_url=')) return;
        const source = frame.src;
        let attempts = 0;
        const ready = setInterval(() => {
            if (frame.src !== source) { clearInterval(ready); return; }
            if (typeof frame.contentWindow?.inject_message === 'function') {
                clearInterval(ready);
                const commands = WAVE_SIGNALS[preset.value].map(n => `variable_add ${prefix}${n}`).join('\n');
                const message = JSON.stringify({LoadCommandFromData: Array.from(new TextEncoder().encode(commands + '\ntoggle_side_panel\n'))});
                frame.contentWindow.postMessage({command: 'InjectMessage', message}, location.origin);
            } else if (++attempts >= 150) {
                clearInterval(ready);
                status.textContent = 'Surfer did not start. Reload waveform to retry.';
            }
        }, 100);
    });

    capture.addEventListener('click', async () => {
        capture.disabled = true;
        status.textContent = 'Capturing…';
        const cycles = parseInt(document.getElementById('capture_cycles').value, 10) || 20000;
        const state = await post({action: 'CAPTURE', cycles});
        capture.disabled = false;
        if (state.error) { status.textContent = state.error; return; }
        status.textContent = `Captured ${cycles} master clocks.`;
        refresh.hidden = false;
        download.hidden = false;
        download.href = `/waveform.fst?capture=${state.captureVersion}`;
        loadWaveform();
    });
    refresh.addEventListener('click', loadWaveform);
    preset.addEventListener('change', loadWaveform);
}

bindWaveform();
loadRoms();
poll();
