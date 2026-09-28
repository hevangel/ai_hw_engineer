/* Each panel keeps a compact restore control when minimized. */
"use strict";
(() => {
  const panels = [
    {name: "calculator", label: "calculator", element: document.getElementById("calculator_panel")},
    {name: "manual", label: "manual examples", element: document.getElementById("manual_panel")}
  ];

  function saved(key, fallback) {
    try { return localStorage.getItem(key) ?? fallback; }
    catch (_) { return fallback; }
  }
  function remember(key, value) {
    try { localStorage.setItem(key, value); }
    catch (_) { /* Storage is optional. */ }
  }
  function setMinimized(panel, minimized, persist = true) {
    panel.element.classList.toggle("minimized", minimized);
    const button = panel.element.querySelector(".panel-minimize");
    const action = minimized ? "Restore" : "Minimize";
    button.textContent = minimized ? "+" : "−";
    button.setAttribute("aria-label", `${action} ${panel.label}`);
    button.setAttribute("aria-expanded", String(!minimized));
    button.title = `${action} ${panel.label}`;
    if (persist) remember(`busicom-${panel.name}-minimized`, String(minimized));
  }
  for (const panel of panels) {
    setMinimized(panel, saved(`busicom-${panel.name}-minimized`, "false") === "true", false);
    panel.element.querySelector(".panel-minimize").addEventListener("click", () =>
      setMinimized(panel, !panel.element.classList.contains("minimized")));
  }

  const waveform = document.getElementById("waveform_panel");
  const icon = waveform.querySelector(".waveform-toggle-icon");
  function syncWaveform() {
    icon.textContent = waveform.open ? "−" : "+";
    waveform.querySelector("summary").title = waveform.open ? "Minimize waveform" : "Restore waveform";
    remember("busicom-waveform-open", String(waveform.open));
  }
  waveform.addEventListener("toggle", syncWaveform);
  waveform.open = saved("busicom-waveform-open", "true") === "true";
  syncWaveform();
})();