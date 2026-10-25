// Space Invaders cabinet. All machine state comes from the RTL.
let currentState = null;
let captureVersion = 0;
let soundOn = false;
const audioCtx = { ctx: null };

// ---- Screen rendering: VRAM is 224 rows x 32 bytes, row 0 = lower-left.
// The cabinet monitor rotates the raster 90 degrees counter-clockwise. We
// draw the unrotated raster to the canvas (256 wide, 224 tall) and rotate
// with CSS. Color gel bands from the CC0 MAME invaders.lay, mapped into
// unrotated coordinates: red x 193..223 (gel y 32..62), green x 15..71
// (gel y 184..240) and partial green x 0..15 (gel y 240..256, gel x 16..134
// covers VRAM rows 16..134).
const canvas = document.getElementById('screen');
const ctx = canvas.getContext('2d');
const img = ctx.createImageData(256, 224);

function renderScreen(vramHex) {
    const vram = new Uint8Array(7168);
    for (let i = 0; i < 7168; ++i)
        vram[i] = (parseInt(vramHex[2 * i], 16) << 4) | parseInt(vramHex[2 * i + 1], 16);
    let p = 0;
    for (let row = 0; row < 224; ++row) {
        for (let col = 0; col < 32; ++col) {
            const byte = vram[row * 32 + col];
            for (let bit = 0; bit < 8; ++bit) {
                // The video hardware shifts VRAM bytes out LSB-first:
                // bit 0 is the leftmost pixel of the 8-pixel group.
                const on = (byte >> bit) & 1;
                const x = col * 8 + bit;
                let r = 8, g = 10, b = 12;
                if (on) {
                    // Gel bands in unrotated-x (= rotated y).
                    if (x >= 193) { r = 255; g = 40; b = 40; }         // UFO zone red
                    else if (x >= 15) { r = 40; g = 255; b = 40; }     // player area green
                    else if (row >= 16 && row <= 134) { r = 40; g = 255; b = 40; } // bottom text
                    else { r = 235; g = 235; b = 235; }                // white
                }
                img.data[p++] = r; img.data[p++] = g; img.data[p++] = b; img.data[p++] = 255;
            }
        }
    }
    ctx.putImageData(img, 0, 0);
}

// ---- Controls: keyboard maps to input-port bits.
// IN1: bit0 credit, bit1 2P start, bit2 1P start, bit4 shot, bit5 left, bit6 right.
// IN2: bit2 tilt, bits4-6 2P controls.
const keys = { in1: 0, in2: 0 };
const KEYMAP = {
    '5': ['in1', 0x01], '7': ['in1', 0x02], '1': ['in1', 0x04],
    ' ': ['in1', 0x10], 'ArrowLeft': ['in1', 0x20], 'ArrowRight': ['in1', 0x40],
    'a': ['in1', 0x20], 'd': ['in1', 0x40], 'f': ['in1', 0x10],
    't': ['in2', 0x04],
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

async function updateInputs() {
    keys.in1 = 0; keys.in2 = 0;
    for (const name of held) {
        const map = KEYMAP[name];
        if (map) keys[map[0]] |= map[1];
    }
    await post({action: 'IN1', value: keys.in1});
    await post({action: 'IN2', value: keys.in2});
}

window.addEventListener('keydown', async event => {
    const name = event.key.length === 1 ? event.key.toLowerCase() : event.key;
    if (!KEYMAP[name] || held.has(name)) return;
    event.preventDefault();
    held.add(name);
    updateInputs();
});
window.addEventListener('keyup', async event => {
    const name = event.key.length === 1 ? event.key.toLowerCase() : event.key;
    if (!held.delete(name)) return;
    updateInputs();
});

// ---- Sound: short WebAudio blips on sound-port bit edges (functional).
const SOUND_NAMES = {
    3: ['ufo', 'shot', 'die', 'invader-die', 'extended', 'amp'],
    5: ['fleet1', 'fleet2', 'fleet3', 'fleet4', 'ufo-hit'],
};
let lastSnd = { 3: 0, 5: 0 };
function playSounds(events) {
    for (const [port, data] of events) {
        const changed = data ^ lastSnd[port];
        lastSnd[port] = data;
        if (!soundOn || !changed) continue;
        for (let bit = 0; bit < 8; ++bit) {
            if (!(changed & (1 << bit))) continue;
            const name = (SOUND_NAMES[port] || [])[bit] || `p${port}b${bit}`;
            beep(name, port === 3 ? 700 - bit * 60 : 240 + bit * 90,
                 (port === 3 && bit === 0) || name.startsWith('fleet') ? 0.25 : 0.09);
        }
    }
}
function beep(name, freq, seconds) {
    if (!audioCtx.ctx) audioCtx.ctx = new AudioContext();
    const osc = audioCtx.ctx.createOscillator();
    const gain = audioCtx.ctx.createGain();
    osc.frequency.value = freq;
    osc.type = 'square';
    gain.gain.setValueAtTime(0.06, audioCtx.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.ctx.currentTime + seconds);
    osc.connect(gain).connect(audioCtx.ctx.destination);
    osc.start();
    osc.stop(audioCtx.ctx.currentTime + seconds);
}

function applyState(state) {
    if (state.error) return;
    currentState = state;
    if (state.captureVersion > captureVersion) captureVersion = state.captureVersion;
    renderScreen(state.vram);
    playSounds(state.snd || []);
    document.getElementById('state_run').textContent = state.running ? 'RUN' : 'STOP';
    document.getElementById('state_run').className = 'state_chip' + (state.running ? ' active' : '');
    document.getElementById('state_fault').hidden = !state.fault;
    document.getElementById('state_wd').hidden = state.watchdogResets === 0;
    const flags = ['S', 'Z', '5', 'AC', '3', 'P', '1', 'C'];
    const rows = [
        ['PC', state.pc.toString(16).padStart(4, '0').toUpperCase()],
        ['SP', state.sp.toString(16).padStart(4, '0').toUpperCase()],
        ['A', hex(state.a)], ['B', hex(state.b)], ['C', hex(state.c)],
        ['D', hex(state.d)], ['E', hex(state.e)], ['H', hex(state.h)], ['L', hex(state.l)],
        ['F', flags.map((n, i) => (state.flags >> (7 - i)) & 1 ? n : '.').join(' ')],
        ['Cycles', state.cycles], ['Instructions', state.instructions],
        ['Frames (60Hz)', state.frames], ['Interrupts', state.interrupts],
        ['Watchdog resets', state.watchdogResets],
        ['Credits (BCD)', hex(state.credit)],
        ['P1 score (BCD)', hex(state.scoreHi) + hex(state.scoreLo)],
        ['Shift register', state.shift.toString(16).padStart(4, '0').toUpperCase() +
            ' >> ' + (8 - state.shiftOffset)],
    ];
    document.getElementById('cpu_table').innerHTML =
        rows.map(([n, v]) => `<tr><th>${n}</th><td>${v}</td></tr>`).join('');
}
const hex = v => (v & 0xff).toString(16).padStart(2, '0').toUpperCase();

async function poll() {
    try {
        const response = await fetch('/api/state');
        const state = await response.json();
        if (!state.error) applyState(state);
    } catch (error) {
        /* backend restarting */
    }
}

document.getElementById('btn_run').addEventListener('click', () => post({action: 'RUNSW'}));
document.getElementById('btn_reset').addEventListener('click', () => post({action: 'RESET'}));
document.getElementById('btn_sound').addEventListener('click', event => {
    soundOn = !soundOn;
    event.target.textContent = soundOn ? 'Sound: on' : 'Sound: off';
    if (soundOn && !audioCtx.ctx) audioCtx.ctx = new AudioContext();
});

// ---- Waveform panel (same Surfer bridge as the Altair/ibm_pc panels).
const WAVE_SIGNALS = {
    cpu: ['clk', 'rst_n', 'retired', 'hold_req', 'cpu.hlda_o', 'cpu.bus_req_o',
          'cpu.bus_write_o', 'cpu.bus_io_o', 'cpu.bus_addr_o', 'cpu.bus_wdata_o',
          'cpu.bus_rdata_i', 'cpu.pc_o', 'cpu.state'],
    video: ['clk', 'irq_pend', 'irq_vec', 'frame_cycle', 'frame_count', 'interrupt_count',
            'cpu.inte_o', 'cpu.bus_intack_o', 'cpu.bus_addr_o'],
    io: ['clk', 'in1', 'in2', 'shift_data_we', 'shift_off_we', 'shifter.reg16',
         'shifter.off', 'shifter.result', 'snd3_we', 'snd3_data', 'snd5_we', 'snd5_data'],
};

function bindWaveform() {
    const frame = document.getElementById('surfer_frame');
    const capture = document.getElementById('waveform_capture');
    const refresh = document.getElementById('waveform_refresh');
    const download = document.getElementById('waveform_download');
    const status = document.getElementById('waveform_status');
    const preset = document.getElementById('waveform_signals');
    const prefix = 'TOP.space_invaders.';

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
        const cycles = parseInt(document.getElementById('capture_cycles').value, 10) || 4096;
        const state = await post({action: 'CAPTURE', cycles});
        capture.disabled = false;
        if (state.error) { status.textContent = state.error; return; }
        status.textContent = `Captured ${cycles} steps.`;
        refresh.hidden = false;
        download.hidden = false;
        download.href = `/waveform.fst?capture=${state.captureVersion}`;
        loadWaveform();
    });
    refresh.addEventListener('click', loadWaveform);
    preset.addEventListener('change', loadWaveform);
}

bindWaveform();
setInterval(poll, 150);
poll();
