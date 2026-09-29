/* The embedded, self-hosted Surfer reads the simulator's FST over HTTP. */
"use strict";
(() => {
  const panel = document.getElementById("waveform_panel");
  const frame = document.getElementById("surfer_frame");
  const status = document.getElementById("waveform_status");
  const refresh = document.getElementById("waveform_refresh");
  const viewerUrl = `${location.protocol}//${location.hostname}:18080/`;
  const defaultSignals = [
    "tb_top.clk", "tb_top.test_i", "tb_top.drum_idx",
    "tb_top.drum_pos", "tb_top.keys_mask", "tb_top.key_seen",
    "tb_top.hammer_evt", "tb_top.advance_evt", "tb_top.lamps",
    // Intel 4004 interface pins; D0–D3 are split into input, output and enable.
    "tb_top.dut.u_cpu.clk", "tb_top.dut.u_cpu.rst_n",
    "tb_top.dut.u_cpu.test_i", "tb_top.dut.u_cpu.data_i",
    "tb_top.dut.u_cpu.data_o", "tb_top.dut.u_cpu.data_oe",
    "tb_top.dut.u_cpu.sync", "tb_top.dut.u_cpu.cm_rom",
    "tb_top.dut.u_cpu.cm_ram"
  ];
  let timer, loadedVersion = "", loading = false;

  function sendCommands(commands) {
    const message = JSON.stringify({LoadCommandFromData:
      Array.from(new TextEncoder().encode(`${commands}\n`))});
    frame.contentWindow?.postMessage({command:"InjectMessage",message},
      new URL(viewerUrl).origin);
  }
  frame.addEventListener("load", () => {
    if (!frame.src.includes("load_url=")) return;
    // Surfer's WASM bridge accepts its own command-file message through
    // postMessage. Allow the FST header to load before adding signal rows.
    const source = frame.src;
    setTimeout(() => {
      if (frame.src !== source) return;
      sendCommands(`${defaultSignals.map(name => `variable_add ${name}`).join("\n")}\ntoggle_side_panel`);
    },1800);
  });

  async function update(force = false) {
    if (!panel.open || loading) return;
    loading = true;
    try {
      const [stateResponse, fstResponse] = await Promise.all([
        fetch("/state.json", {cache:"no-store"}),
        fetch("/waveform.fst", {method:"HEAD",cache:"no-store"})
      ]);
      if (!stateResponse.ok || !fstResponse.ok) {
        status.textContent = "No FST capture yet. Run a calculation, then refresh.";
        if (!frame.src) frame.src = viewerUrl;
        return;
      }
      const state = await stateResponse.json();
      const bytes = Number(fstResponse.headers.get("Content-Length"));
      const version = fstResponse.headers.get("X-Waveform-Version") || String(bytes);
      if (state.busy || window.manualReplayActive) {
        status.textContent = "Recording the current calculation…";
        return;
      }
      if (!force && version === loadedVersion) return;
      if (bytes < 128) {
        status.textContent = "Run a calculation to record hardware signals.";
        if (!frame.src) frame.src = viewerUrl;
        return;
      }
      const fstUrl = `${location.origin}/waveform.fst?capture=${Date.now()}`;
      frame.src = `${viewerUrl}?load_url=${encodeURIComponent(fstUrl)}`;
      loadedVersion = version;
      status.textContent = `Surfer · ${Math.max(1,Math.round(bytes / 1024))} KiB FST · latest key or paper advance`;
    } catch (error) {
      status.textContent = `Could not open waveform: ${error.message}`;
    } finally {
      loading = false;
    }
  }
  panel.addEventListener("toggle", () => {
    if (panel.open) {
      update(true);
      timer = setInterval(update, 1000);
    } else {
      clearInterval(timer);
    }
  });
  refresh.addEventListener("click", () => update(true));
})();
