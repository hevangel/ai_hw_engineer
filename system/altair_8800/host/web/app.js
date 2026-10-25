// Altair 8800 web front panel. All displayed state comes from the RTL.
const STATUS_LAMPS = ['MEMR', 'INP', 'M1', 'OUT', 'HLTA', 'STACK', 'WO', 'INT'];
const CPU_LAMPS = ['INTE', 'HLDA', 'PROT', 'WAIT', 'HALT'];
const A_LAMPS = 16;

let currentState = null;
let consoleText = '';
let captureVersion = 0;

function lampSpan(bit, label) {
    const span = document.createElement('span');
    span.className = 'lamp' + (bit ? ' on' : '');
    span.textContent = label || '';
    return span;
}

function toggleSpan(bit, index, group) {
    const span = document.createElement('span');
    span.className = 'toggle' + (bit ? ' up' : '');
    span.textContent = bit;
    span.addEventListener('click', () => flipSwitch(group, index, bit));
    return span;
}

async function post(body) {
    const response = await fetch('/api/control', {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
    });
    const data = await response.json();
    if (data.error) console.warn(data.error);
    if (data && !data.error) applyState(data);
    return data;
}

async function flipSwitch(group, index, current) {
    if (!currentState) return;
    if (group === 'addr') {
        const mask = 1 << (15 - index);
        const next = current ? currentState.switchAddr & ~mask : currentState.switchAddr | mask;
        await post({action: 'SWITCHES', address: next, data: currentState.switchData});
    } else {
        const mask = 1 << (7 - index);
        const next = current ? currentState.switchData & ~mask : currentState.switchData | mask;
        await post({action: 'SWITCHES', address: currentState.switchAddr, data: next});
    }
}

function buildLamps() {
    const fill = (id, count, render) => {
        const host = document.getElementById(id);
        host.innerHTML = '';
        for (let i = 0; i < count; ++i) host.appendChild(render(i));
    };
    fill('addr_hi', 8, i => lampSpan(0));
    fill('addr_lo', 8, i => lampSpan(0));
    fill('data_lamps', 8, i => lampSpan(0));
    fill('status_lamps', 8, i => lampSpan(0, STATUS_LAMPS[i]));
    fill('cpu_lamps', CPU_LAMPS.length, i => lampSpan(0, CPU_LAMPS[i]));
    fill('sw_addr_hi', 8, i => toggleSpan(0, i, 'addr'));
    fill('sw_addr_lo', 8, i => toggleSpan(0, i + 8, 'addr'));
    fill('sw_data', 8, i => toggleSpan(0, i, 'data'));
}

function hex(value, width) {
    return value.toString(16).toUpperCase().padStart(width, '0');
}

function applyState(state) {
    if (state.error) return;
    currentState = state;
    if (state.captureVersion > captureVersion) captureVersion = state.captureVersion;
    const setLamps = (id, values, labels) => {
        const host = document.getElementById(id);
        for (let i = 0; i < host.children.length && i < values.length; ++i) {
            const child = host.children[i];
            child.className = 'lamp' + (values[i] ? ' on' : '');
        }
    };
    const addrBits = [];
    for (let i = 0; i < A_LAMPS; ++i) addrBits.push((state.lampAddr >> (15 - i)) & 1);
    setLamps('addr_hi', addrBits.slice(0, 8));
    setLamps('addr_lo', addrBits.slice(8));
    const dataBits = [];
    for (let i = 0; i < 8; ++i) dataBits.push((state.lampData >> (7 - i)) & 1);
    setLamps('data_lamps', dataBits);
    setLamps('status_lamps', Array.from({length: 8}, (_, i) => (state.lampStatus >> (7 - i)) & 1));
    setLamps('cpu_lamps', [state.inte, state.hlda, state.protected, false, state.lampHlta || state.halted]);
    document.getElementById('state_run').textContent = state.running ? 'RUN' : 'STOP';
    document.getElementById('state_run').className = 'state_chip' + (state.running ? ' active' : '');
    document.getElementById('state_halt').className = 'state_chip' + (state.halted ? ' active' : '');
    document.getElementById('state_prot').textContent = state.protected ? 'PROTECTED' : 'UNPROTECTED';
    document.getElementById('state_prot').className = 'state_chip' + (state.protected ? ' active' : '');
    document.getElementById('state_fault').hidden = !state.fault;

    const setToggles = (id, values) => {
        const host = document.getElementById(id);
        for (let i = 0; i < host.children.length && i < values.length; ++i) {
            host.children[i].className = 'toggle' + (values[i] ? ' up' : '');
            host.children[i].textContent = values[i] ? 1 : 0;
        }
    };
    const swBits = [];
    for (let i = 0; i < A_LAMPS; ++i) swBits.push((state.switchAddr >> (15 - i)) & 1);
    setToggles('sw_addr_hi', swBits.slice(0, 8));
    setToggles('sw_addr_lo', swBits.slice(8));
    const swData = [];
    for (let i = 0; i < 8; ++i) swData.push((state.switchData >> (7 - i)) & 1);
    setToggles('sw_data', swData);

    // Console text: teletype bytes accumulated since the last poll.
    if (state.tx.length) {
        for (const byte of state.tx) {
            const ch = String.fromCharCode(byte & 0x7f);
            consoleText += ch === '\r' ? '\n' : ch;
        }
        if (consoleText.length > 20000) consoleText = consoleText.slice(-16000);
        const tty = document.getElementById('tty_out');
        tty.textContent = consoleText;
        tty.scrollTop = tty.scrollHeight;
    }

    const flags = ['S', 'Z', '5', 'AC', '3', 'P', '1', 'C'];
    const rows = [
        ['PC', hex(state.pc, 4)], ['SP', hex(state.sp, 4)],
        ['A', hex(state.a, 2)], ['B', hex(state.b, 2)], ['C', hex(state.c, 2)],
        ['D', hex(state.d, 2)], ['E', hex(state.e, 2)], ['H', hex(state.h, 2)],
        ['L', hex(state.l, 2)],
        ['F', flags.map((name, i) => (state.flags >> (7 - i)) & 1 ? name : '.').join(' ')],
        ['Cycles', state.cycles], ['Instructions', state.instructions],
        ['SIO RX queue', state.rxCount], ['Tape pending', state.tapePending],
    ];
    const table = document.getElementById('cpu_table');
    table.innerHTML = rows.map(([name, value]) =>
        `<tr><th>${name}</th><td>${value}</td></tr>`).join('');
    const mem = state.mem.map((byte, i) =>
        `${hex((state.memBase + i) & 0xffff, 4)}: ${hex(byte, 2)} ` +
        `${(byte & 0x7f) >= 32 && (byte & 0x7f) < 127 ? String.fromCharCode(byte & 0x7f) : '.'}`
    ).join('\n');
    document.getElementById('mem_window').textContent = mem;
}

async function poll() {
    try {
        const response = await fetch('/api/state');
        const state = await response.json();
        if (!state.error) applyState(state);
    } catch (error) {
        /* backend restarting */
    }
}

function bindControls() {
    const actions = {
        btn_run: {action: 'RUNSW', value: () => !(currentState && currentState.running)},
        btn_step: {action: 'STEP'},
        btn_examine: {action: 'EXAMINE'},
        btn_exnext: {action: 'EXNEXT'},
        btn_deposit: {action: 'DEPOSIT'},
        btn_depnext: {action: 'DEPNEXT'},
        btn_reset: {action: 'RESET'},
        btn_clr: {action: 'CLR'},
        btn_protect: {action: 'PROTECT'},
        btn_unprotect: {action: 'UNPROTECT'},
    };
    for (const [id, spec] of Object.entries(actions)) {
        document.getElementById(id).addEventListener('click', () => {
            const body = {action: spec.action};
            if (spec.value !== undefined) body.value = spec.value();
            post(body);
        });
    }
    document.getElementById('tty_form').addEventListener('submit', async event => {
        event.preventDefault();
        const input = document.getElementById('tty_in');
        const keys = [...(input.value + '\r')].map(ch => ch.charCodeAt(0) & 0x7f);
        input.value = '';
        await post({action: 'KEY', keys});
    });
    document.getElementById('tape_file').addEventListener('change', async event => {
        const file = event.target.files[0];
        if (!file) return;
        const bytes = new Uint8Array(await file.arrayBuffer());
        const response = await fetch('/api/tape', {method: 'POST', body: bytes});
        const data = await response.json();
        if (data.error) {
            document.getElementById('waveform_status').textContent = data.error;
        } else {
            consoleText += `[tape loaded: ${file.name}]\n`;
            applyState(data);
        }
        event.target.value = '';
    });
    document.getElementById('tape_basic').addEventListener('click', () => post({action: 'LOADBASIC'}));
    document.getElementById('tape_stop').addEventListener('click', () => post({action: 'TAPEOFF'}));
    bindWaveform();
}

const WAVE_SIGNALS = {
    cpu: ['clk', 'rst_n', 'retired', 'hold_req', 'cpu.hlda_o', 'cpu.bus_req_o', 'cpu.bus_write_o',
          'cpu.bus_io_o', 'cpu.bus_addr_o', 'cpu.bus_wdata_o', 'cpu.bus_rdata_i', 'cpu.bus_status_o',
          'cpu.pc_o', 'cpu.state'],
    sio: ['clk', 'tty_in_we', 'tty_in_data', 'tty_in_ready', 'tty_out_we', 'tty_out_data',
          'tx_busy', 'rx_wr_ptr', 'rx_rd_ptr', 'cpu.bus_io_o', 'cpu.bus_addr_o'],
    panel: ['clk', 'rst_n', 'run_sw', 'stepping', 'step_sw', 'examine_sw', 'deposit_sw',
            'deposit_next_sw', 'reset_sw', 'lamp_hlda', 'lamp_addr', 'lamp_data', 'lamp_status',
            'display_addr', 'cpu.bus_req_o'],
};

function bindWaveform() {
    const frame = document.getElementById('surfer_frame');
    const capture = document.getElementById('waveform_capture');
    const refresh = document.getElementById('waveform_refresh');
    const download = document.getElementById('waveform_download');
    const status = document.getElementById('waveform_status');
    const preset = document.getElementById('waveform_signals');
    const prefix = 'TOP.altair_8800.';

    const loadWaveform = () => {
        if (!captureVersion) return;
        const url = new URL('/surfer/', location.origin);
        url.searchParams.set('load_url', `${location.origin}/waveform.fst?capture=${captureVersion}`);
        url.searchParams.set('view', preset.value);
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
                const commands = WAVE_SIGNALS[preset.value].map(name => `variable_add ${prefix}${name}`).join('\n');
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
        if (state.error) {
            status.textContent = state.error;
            return;
        }
        status.textContent = `Captured ${cycles} steps from step ${state.cycles - cycles}.`;
        refresh.hidden = false;
        download.hidden = false;
        download.href = `/waveform.fst?capture=${state.captureVersion}`;
        loadWaveform();
    });
    refresh.addEventListener('click', loadWaveform);
    preset.addEventListener('change', loadWaveform);
}

buildLamps();
bindControls();
setInterval(poll, 120);
poll();
