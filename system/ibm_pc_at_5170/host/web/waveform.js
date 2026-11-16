// Waveform panel: capture a window of processor clocks to FST and show it
// in the self-hosted Surfer (/surfer/), as the other systems' panels do.
import {control, currentState} from './app.js';

const $ = id => document.getElementById(id);
const panel = $('waveform_panel'), frame = $('surfer_frame'), capture = $('waveform_capture');
const refresh = $('waveform_refresh'), status = $('waveform_status'), preset = $('waveform_signals');
const download = $('waveform_download');
// Signals of host/ibm_pc_at_5170_vga_host.sv (traced at depth 1).
const prefix = 'TOP.ibm_pc_at_5170_vga_host.';
const signals = {
  cpu: ['clk_i', 'reset_i', 'cpu_reset_o', 'cs_o', 'ip_o', 'retire_o', 'address_o', 'io_cycle_o',
    'fetch_cycle_o', 'data_oe_o', 'bhe_n_o', 'completed_bytes_o', 'data_o', 'cpu_data_o', 'mem_rdata_i',
    'io_port_o', 'chan_sel_o', 'intr_o', 'inta_cycle_o', 'refresh_o', 'post_code_o'],
  keyboard: ['clk_i', 'kbd_clk_i', 'kbd_data_i', 'kbd_clk_o', 'kbd_data_o', 'kbc_p2_o', 'kbc_obf_o',
    'intr_o', 'inta_cycle_o', 'io_cycle_o', 'io_port_o', 'cpu_data_o', 'cs_o', 'ip_o'],
  video: ['vid_clk_i', 'pix_en_o', 'hsync_o', 'vsync_o', 'de_o', 'r_o', 'g_o', 'b_o', 'chan_sel_o',
    'address_o', 'data_o', 'cs_o', 'ip_o'],
};
let loaded = 0, busy = false, failure = '';

function load(force = false) {
  const s = currentState();
  if (!panel.open || !s?.captureVersion || (!force && loaded === s.captureVersion)) return;
  loaded = s.captureVersion;
  failure = '';
  const url = new URL('/surfer/', location.origin);
  url.searchParams.set('load_url', `${location.origin}/waveform.fst?capture=${loaded}`);
  url.searchParams.set('view', preset.value);
  url.hash = 'dev';
  frame.src = url.href;
}

frame.addEventListener('load', () => {
  if (!frame.src.includes('load_url=')) return;
  const source = frame.src;
  let attempts = 0;
  const ready = setInterval(() => {
    if (frame.src !== source) { clearInterval(ready); return; }
    if (typeof frame.contentWindow?.inject_message === 'function') {
      clearInterval(ready);
      const commands = signals[preset.value].map(n => `variable_add ${prefix}${n}`).join('\n');
      const message = JSON.stringify({LoadCommandFromData: Array.from(new TextEncoder().encode(commands + '\nzoom_fit\ntoggle_side_panel\n'))});
      frame.contentWindow.postMessage({command: 'InjectMessage', message}, location.origin);
    } else if (++attempts >= 150) {
      clearInterval(ready); failure = 'Surfer did not start. Reload the waveform to retry.'; update();
    }
  }, 100);
});

function update() {
  const s = currentState();
  capture.disabled = busy || !s?.powered || !!s?.stopped;
  refresh.disabled = busy || !s?.captureVersion;
  download.hidden = !s?.captureVersion;
  if (busy) return;
  if (failure) { status.textContent = failure; return; }
  if (s?.captureVersion) {
    status.textContent = `Capture ${s.captureVersion}: processor clocks ${s.captureStart.toLocaleString('en-US')} to ` +
      `${(s.captureStart + s.captureClocks).toLocaleString('en-US')} (${s.captureClocks.toLocaleString('en-US')} clocks; ` +
      'time axis 41.67 ns per clock, the AT19 time base)';
    load();
  } else {
    status.textContent = s?.powered ? 'Ready to capture.' : 'Power on, then capture a waveform.';
  }
}

capture.onclick = async () => {
  busy = true; failure = ''; update(); status.textContent = 'Recording…';
  try {
    if (!await control('CAPTURE', {clocks: Number($('waveform_clocks').value)})) throw Error('Capture failed.');
  } catch (e) { failure = e.message; }
  finally { busy = false; update(); }
};
refresh.onclick = () => load(true);
preset.onchange = () => load(true);
panel.addEventListener('toggle', () => { if (panel.open) update(); });
setInterval(update, 500);
update();
