// Commodore 64 front panel. All machine state comes from the RTL.
let captureVersion = 0;

// ---- Screen: the simulator returns the 520x312 dot raster as one palette
// index per hex digit; the canvas shows the visible area with the border.
const PALETTE = [0x000000, 0xffffff, 0x813338, 0x75cec8, 0x8e3c97, 0x56ac4d, 0x2e2c9b, 0xedf171,
                 0x8e5029, 0x553800, 0xc46c71, 0x4a4a4a, 0x7b7b7b, 0xa9ff9f, 0x706deb, 0xb2b2b2];
const CROP = {top: 16, left: 80, width: 400, height: 284};
const canvas = document.getElementById('screen');
const ctx = canvas.getContext('2d');
const img = ctx.createImageData(CROP.width, CROP.height);

function renderScreen(state) {
    const frame = state.frame, cols = state.cols;
    let p = 0;
    for (let y = 0; y < CROP.height; ++y) {
        const base = (y + CROP.top) * cols + CROP.left;
        for (let x = 0; x < CROP.width; ++x) {
            const c = PALETTE[parseInt(frame[base + x], 16)];
            img.data[p++] = c >> 16; img.data[p++] = (c >> 8) & 255;
            img.data[p++] = c & 255; img.data[p++] = 255;
        }
    }
    ctx.putImageData(img, 0, 0);
}

async function post(body) {
    const response = await fetch('/api/control', {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
    });
    const data = await response.json();
    if (!data.error) applyState(data);
    return data;
}

// ---- Keyboard: printable keys are queued and typed by the server (the
// simulation is slower than real time, so a browser key press is shorter
// than one KERNAL scan). Arrows and Ctrl drive joystick port 2.
const TYPED = /^[a-zA-Z0-9 +\-.:@,*;=\/!"#$%&'()<>?\[\]]$/;
const JOY = {ArrowUp: 1, ArrowDown: 2, ArrowLeft: 4, ArrowRight: 8, Control: 16};
let joy = 0;

canvas.addEventListener('keydown', event => {
    if (JOY[event.key]) {
        event.preventDefault();
        joy |= JOY[event.key];
        post({action: 'JOY2', value: 31 & ~joy});
    } else if (event.key === 'Enter') {
        event.preventDefault();
        post({action: 'TYPE', text: '\n'});
    } else if (TYPED.test(event.key) && !event.ctrlKey && !event.metaKey) {
        event.preventDefault();
        post({action: 'TYPE', text: event.key});
    }
});
canvas.addEventListener('keyup', event => {
    if (!JOY[event.key]) return;
    joy &= ~JOY[event.key];
    post({action: 'JOY2', value: 31 & ~joy});
});

const hex = (v, n = 2) => v.toString(16).padStart(n, '0').toUpperCase();

function applyState(state) {
    if (state.error) return;
    if (state.captureVersion > captureVersion) captureVersion = state.captureVersion;
    if (state.frame) renderScreen(state);
    const run = document.getElementById('state_run');
    run.textContent = state.running ? 'RUN' : 'STOP';
    run.className = 'state_chip' + (state.running ? ' active' : '');
    document.getElementById('state_variant').textContent = state.variant;
    document.getElementById('state_jam').hidden = !state.jammed;
    const flags = ['N', 'V', '1', 'B', 'D', 'I', 'Z', 'C'];
    const rows = [
        ['PC', hex(state.pc, 4)], ['A', hex(state.a)], ['X', hex(state.x)],
        ['Y', hex(state.y)], ['S', hex(state.s)],
        ['P', flags.map((n, i) => (state.p >> (7 - i)) & 1 ? n : '.').join(' ')],
        ['CPU cycles', state.cycles], ['Frames', state.frames],
        ['Text screen', '$' + hex(state.screenBase, 4)],
        ['Typing queue', state.queued],
    ];
    document.getElementById('cpu_table').innerHTML =
        rows.map(([n, v]) => `<tr><th>${n}</th><td>${v}</td></tr>`).join('');
}

let polling = false;
async function poll() {
    if (polling) return;
    polling = true;
    try {
        const response = await fetch('/api/state');
        const state = await response.json();
        if (!state.error) applyState(state);
    } catch (error) {
        /* backend restarting */
    } finally {
        polling = false;
    }
}

document.getElementById('btn_run').addEventListener('click', () => post({action: 'RUNSW'}));
document.getElementById('btn_reset').addEventListener('click', () => post({action: 'RESET'}));
document.getElementById('btn_restore').addEventListener('click', () => post({action: 'RESTORE'}));
document.getElementById('btn_stop_restore').addEventListener('click', () => post({action: 'STOPRESTORE'}));
const typeText = document.getElementById('type_text');
const typeNow = () => {
    if (typeText.value) post({action: 'TYPE', text: typeText.value + '\n'});
    typeText.value = '';
};
document.getElementById('btn_type').addEventListener('click', typeNow);
typeText.addEventListener('keydown', event => { if (event.key === 'Enter') typeNow(); });

// ---- Waveform panel (same Surfer bridge as the other system panels).
const WAVE_SIGNALS = {
    cpu: ['clk', 'phi2', 'cpu_addr', 'cpu_data_in', 'cpu_data_out', 'cpu_we', 'cpu_fetch',
          'cpu_pc', 'cpu_a', 'cpu_x', 'cpu_y', 'cpu_s', 'cpu_p'],
    vic: ['clk', 'phi2', 'ba', 'aec', 'irq_n', 'nmi_n', 'raster_line', 'raster_cycle',
          'pixel_valid', 'pixel', 'cpu_addr'],
    io: ['clk', 'phi2', 'cpu_addr', 'pla_out', 'iec_atn_n', 'iec_clk_n', 'iec_data_n',
         'sid_ce', 'sid_wave', 'sid_env', 'sid_mode_vol'],
};

function bindWaveform() {
    const frame = document.getElementById('surfer_frame');
    const capture = document.getElementById('waveform_capture');
    const refresh = document.getElementById('waveform_refresh');
    const download = document.getElementById('waveform_download');
    const status = document.getElementById('waveform_status');
    const preset = document.getElementById('waveform_signals');
    const prefix = 'TOP.c64_board.';
    let surfer = true;
    fetch('/api/health').then(r => r.json()).then(h => {
        surfer = h.surfer;
        frame.hidden = !surfer;
        if (!surfer) status.textContent = 'Surfer is not installed here; captures can still be downloaded.';
    }).catch(() => {});

    const loadWaveform = () => {
        if (!captureVersion || !surfer) return;
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
        const cycles = parseInt(document.getElementById('capture_cycles').value, 10) || 2000;
        const state = await post({action: 'CAPTURE', cycles});
        capture.disabled = false;
        if (state.error) { status.textContent = state.error; return; }
        status.textContent = `Captured ${cycles} CPU cycles.` + (surfer ? '' : ' Surfer is not installed here.');
        refresh.hidden = !surfer;
        download.hidden = false;
        download.href = `/waveform.fst?capture=${state.captureVersion}`;
        loadWaveform();
    });
    refresh.addEventListener('click', loadWaveform);
    preset.addEventListener('change', loadWaveform);
}

bindWaveform();
setInterval(poll, 250);
poll();
