// NES panel. All machine state comes from the RTL; the browser only turns
// palette indices into colours and DAC codes into sound.
let captureVersion = 0;
let soundOn = false;
let audio = null;
let audioTime = 0;

// ---- Palette: decode each 2C02 colour index the way a TV decodes the
// composite signal. Levels are the NESdev "NTSC video" measurements; the
// square-wave chroma phase per hue is demodulated to YIQ, then RGB.
const LO = [0.350, 0.518, 0.962, 1.550];
const HI = [1.094, 1.506, 1.962, 1.962];
const BLACK = 0.518, WHITE = 1.962;
function decode(index, emphasis) {
    const hue = index & 15, level = (index >> 4) & 3;
    if (hue >= 14) return [0, 0, 0];
    let y = 0, i = 0, q = 0;
    for (let p = 0; p < 12; ++p) {
        let v = hue === 0 ? HI[level] : hue === 13 ? LO[level]
              : ((hue + p) % 12 < 6 ? HI[level] : LO[level]);
        // Emphasis bits attenuate the signal during their colour phases.
        if (emphasis && hue < 14) {
            const tint = ((emphasis & 1) && (p + 4) % 12 < 6) ||
                         ((emphasis & 2) && (p + 8) % 12 < 6) ||
                         ((emphasis & 4) && p % 12 < 6);
            if (tint) v *= 0.746;
        }
        v = (v - BLACK) / (WHITE - BLACK);
        const a = Math.PI * (p + 3.9) / 6;
        y += v / 12; i += v * Math.cos(a) / 12; q += v * Math.sin(a) / 12;
    }
    const rgb = [y + 0.946882 * i + 0.623557 * q,
                 y - 0.274788 * i - 0.635691 * q,
                 y - 1.108545 * i + 1.709007 * q];
    return rgb.map(c => Math.max(0, Math.min(255, Math.round(c * 1.1 * 255))));
}
const PALETTE = Array.from({length: 64}, (_, n) => decode(n, 0));

const canvas = document.getElementById('screen');
const ctx = canvas.getContext('2d');
const img = ctx.createImageData(256, 240);

function renderScreen(b64) {
    const raw = atob(b64);
    for (let n = 0, p = 0; n < 256 * 240; ++n) {
        const [r, g, b] = PALETTE[raw.charCodeAt(n) & 63];
        img.data[p++] = r; img.data[p++] = g; img.data[p++] = b; img.data[p++] = 255;
    }
    ctx.putImageData(img, 0, 0);
}

// ---- Audio: the board's mixer output arrives as 44.1 kHz int16 blocks.
function playAudio(b64) {
    if (!soundOn || !b64) return;
    if (!audio) audio = new AudioContext({sampleRate: 44100});
    const raw = atob(b64);
    const count = raw.length >> 1;
    if (!count) return;
    const buffer = audio.createBuffer(1, count, 44100);
    const data = buffer.getChannelData(0);
    for (let n = 0; n < count; ++n) {
        let v = raw.charCodeAt(2 * n) | (raw.charCodeAt(2 * n + 1) << 8);
        if (v & 0x8000) v -= 0x10000;
        data[n] = v / 32768;
    }
    const source = audio.createBufferSource();
    source.buffer = buffer;
    source.connect(audio.destination);
    audioTime = Math.max(audioTime, audio.currentTime + 0.05);
    source.start(audioTime);
    audioTime += buffer.duration;
}

// ---- Controller 1: {Right, Left, Down, Up, Start, Select, B, A}, 1 = pressed.
const KEYMAP = {
    'x': 0x01, 'z': 0x02, 'Shift': 0x04, 'Enter': 0x08,
    'ArrowUp': 0x10, 'ArrowDown': 0x20, 'ArrowLeft': 0x40, 'ArrowRight': 0x80,
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
    document.getElementById('state_jam').hidden = !(state.jammed || state.fault);
    const flags = ['N', 'V', '-', 'B', 'D', 'I', 'Z', 'C'];
    const rows = [
        ['Cartridge', state.rom || '—'],
        ['PC', hex(state.pc, 4)], ['A', hex(state.a)], ['X', hex(state.x)],
        ['Y', hex(state.y)], ['S', hex(state.s)],
        ['P', flags.map((n, k) => (state.p >> (7 - k)) & 1 ? n : '.').join(' ')],
        ['Raster', `line ${state.scanline}, dot ${state.dot}`],
        ['Frames', state.frames], ['CPU cycles', state.cycles],
        ['Controller 1', hex(state.pad1)],
    ];
    document.getElementById('cpu_table').innerHTML =
        rows.map(([n, v]) => `<tr><th>${n}</th><td>${v}</td></tr>`).join('');
    document.getElementById('test_text').textContent = state.testText || '';
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
    if (soundOn && !audio) audio = new AudioContext({sampleRate: 44100});
});

// ---- Waveform panel (same Surfer bridge as the other system panels).
const WAVE_SIGNALS = {
    cpu: ['clk', 'cpu_clk', 'cpu_tick', 'cpu_addr', 'cpu_data', 'cpu_we', 'cpu_fetch',
          'cpu_dma', 'nmi_n', 'cpu_pc', 'cpu_a', 'cpu_x', 'cpu_y', 'cpu_s', 'cpu_p'],
    ppu: ['clk', 'dot_ce', 'scanline', 'dot', 'pixel', 'pixel_valid', 'nmi_n',
          'vram_addr', 'vram_rdata', 'vram_we', 'vram_wdata', 'ppu.v', 'ppu.t', 'ppu.vbl',
          'ppu.sprite0_hit'],
    apu: ['cpu_clk', 'pulse1', 'pulse2', 'triangle', 'noise', 'dmc', 'cpu_dma',
          'cpu.dma.halted', 'cpu.dma.oam_active', 'exp_out', 'cpu_addr', 'cpu_data'],
};

function bindWaveform() {
    const frame = document.getElementById('surfer_frame');
    const capture = document.getElementById('waveform_capture');
    const refresh = document.getElementById('waveform_refresh');
    const download = document.getElementById('waveform_download');
    const status = document.getElementById('waveform_status');
    const preset = document.getElementById('waveform_signals');
    const prefix = 'TOP.nes.';

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
