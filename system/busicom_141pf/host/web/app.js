/* BUSICOM 141-PF virtual front panel - browser side. */
"use strict";

const PAPER_ROWS = 7;
const PAPER_COLS = 18;

const paperTable = document.getElementById("paper");
const drumTable = document.getElementById("drum");

/* build the paper grid once: rows of cells + a red class on <tr> */
for (let r = 0; r < PAPER_ROWS; r++) {
  const tr = document.createElement("tr");
  for (let c = 0; c < PAPER_COLS; c++) {
    const td = document.createElement("td");
    td.textContent = " ";
    tr.appendChild(td);
  }
  paperTable.appendChild(tr);
}
const drumRow = drumTable.insertRow();
for (let c = 0; c < PAPER_COLS; c++) {
  const td = document.createElement("td");
  td.textContent = " ";
  drumRow.appendChild(td);
}

/* A snapshot retains the latest real strike per column, even between polls.
 * Hold each flash for two seconds; this is a visualization, not mechanical timing. */
const hammerElements = [];
const strikeIds = Array(PAPER_COLS).fill(0);
const strikeTimers = [];
let haveStrikeSnapshot = false;
let strikeCount = 0;
let ribbonTimer;
for (let c = 0; c < PAPER_COLS; c++) {
  const hammer = document.createElement("span");
  hammer.className = c === 15 ? "hammer spacer" : "hammer";
  hammer.title = `Print hammer ${c + 1}`;
  document.getElementById("hammers").appendChild(hammer);
  hammerElements.push(hammer);
}
function showStrikes(strikes) {
  if (!Array.isArray(strikes)) return;
  const newest = [];
  strikes.forEach((strike, c) => {
    if (c >= PAPER_COLS) return;
    if (haveStrikeSnapshot && strike.id > strikeIds[c]) {
      const hammer = hammerElements[c];
      clearTimeout(strikeTimers[c]);
      hammer.textContent = strike.char;
      hammer.className = `hammer striking${strike.red ? " red" : ""}`;
      hammer.title = `${strike.red ? "Red" : "Black"} ribbon: ${strike.char}`;
      newest.push({ ...strike, column: c + 1 });
      strikeTimers[c] = setTimeout(() => {
        hammer.className = "hammer";
        hammer.textContent = "";
      }, 2000);
    }
    strikeIds[c] = strike.id;
  });
  haveStrikeSnapshot = true;
  if (newest.length) {
    strikeCount += newest.length;
    document.getElementById("strike_count").textContent = `${strikeCount} strikes observed`;
    const status = document.getElementById("strike_status");
    const last = newest.at(-1);
    status.textContent = `Last strike: ${last.char} · column ${last.column} · ${last.red ? "red" : "black"} ribbon`;
    const ribbon = document.getElementById("ribbon");
    ribbon.className = `ribbon active-${last.red ? "red" : "black"}`;
    clearTimeout(ribbonTimer);
    ribbonTimer = setTimeout(() => { ribbon.className = "ribbon"; }, 2000);
  }
}
const helpDialog = document.getElementById("help_dialog");
document.getElementById("help_open").addEventListener("click", () => helpDialog.showModal());

function post(path, body) {
  return fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body || {}),
  });
}

/* ---- busy state: while the 4004 is working a key press, block new
 * input and show a spinner. Driven by the bridge's `busy` flag in
 * state.json; set optimistically on click so double-clicks can't
 * queue a second press before the next poll. ---- */
let busy = false;
const busyEl = document.getElementById("busy");
const keyBtns = Array.from(document.querySelectorAll("#keyboard .key"));
const advanceBtn = document.getElementById("advance");

function setBusy(b) {
  b = b || !!window.manualReplayActive;
  if (busy === b) return;
  busy = b;
  busyEl.hidden = !b;
  keyBtns.forEach((btn) => { btn.disabled = b; });
  advanceBtn.disabled = b;
  document.body.classList.toggle("is-busy", b);
}
setBusy(true); // wait for the first successful status response

/* ---- front panel inputs ---- */
keyBtns.forEach((btn) => {
  btn.addEventListener("click", () => {
    if (busy) return;
    setBusy(true);
    post("/press", { code: parseInt(btn.getAttribute("code"), 10) })
      .catch(() => setBusy(false));
  });
});
advanceBtn.addEventListener("click", () => {
  if (busy) return;
  setBusy(true);
  post("/advance", {}).catch(() => setBusy(false));
});

const digitsSlider = document.getElementById("digits");
const digitsLabel = document.getElementById("digits_label");
/* Decimal-point selector: the real machine has 8 positions mapping to
   values 0,1,2,3,4,5,6,8 (there is no 7) — user manual, key functions. */
const DP_VALUES = [0, 1, 2, 3, 4, 5, 6, 8];
const dpToSlider = (v) => Math.max(0, DP_VALUES.indexOf(v));
digitsSlider.addEventListener("input", () => {
  const v = DP_VALUES[parseInt(digitsSlider.value, 10)];
  digitsLabel.textContent = v;
  post("/switches", { precision: v });
});
document.querySelectorAll('input[name="rounding"]').forEach((radio) => {
  radio.addEventListener("change", () => {
    if (radio.checked)
      post("/switches", { rounding: parseInt(radio.value, 10) });
  });
});

/* physical keyboard, matching the original emulator mapping */
const keymap = {
  "0": 156, "1": 155, "2": 151, "3": 147, "4": 154, "5": 150,
  "6": 146, "7": 153, "8": 149, "9": 145,
  ".": 148, "+": 142, "-": 141, "*": 139, "/": 138,
  "=": 140, Enter: 140, "%": 134, "#": 137,
};
document.addEventListener("keydown", (e) => {
  if (helpDialog.open || e.target.closest('.manual-replay, input, select, textarea')) return;
  const code = keymap[e.key];
  if (code) {
    if (busy) return;
    setBusy(true);
    post("/press", { code }).catch(() => setBusy(false));
    const btn = document.querySelector(`#keyboard .key[code="${code}"]`);
    if (btn) {
      btn.classList.add("pressed");
      setTimeout(() => btn.classList.remove("pressed"), 120);
    }
    e.preventDefault();
  }
});

/* ---- state polling ---- */
function setLed(id, on, cls) {
  const el = document.getElementById(id);
  el.className = on ? `led on-${cls}` : "led";
  el.setAttribute("aria-label", `${cls} lamp ${on ? "on" : "off"}`);
}

async function poll() {
  try {
    const r = await fetch("state.json");
    const s = await r.json();

    for (let row = 0; row < PAPER_ROWS; row++) {
      const tr = paperTable.rows[row];
      tr.className = s.paper[row][PAPER_COLS] ? "red" : "";
      for (let c = 0; c < PAPER_COLS; c++) {
        const cell = tr.cells[c];
        const ch = s.paper[row][c];
        if (cell.textContent !== ch)
          cell.textContent = ch;
      }
    }
    for (let c = 0; c < PAPER_COLS; c++) {
      const cell = drumTable.rows[0].cells[c];
      if (cell.textContent !== s.drumRow[c])
        cell.textContent = s.drumRow[c];
    }
    showStrikes(s.strikes);
    setLed("led_memory", s.lamps.memory, "memory");
    setLed("led_overflow", s.lamps.overflow, "overflow");
    setLed("led_negative", s.lamps.negative, "negative");

    /* the bridge clears busy when the 4004 is idle again */
    busyEl.querySelector(".busy-label").textContent = s.ready === 0
      ? "Starting 4004…" : "4004 working…";
    setBusy(!!s.busy);

    const sliderPos = dpToSlider(s.precision);
    if (parseInt(digitsSlider.value, 10) !== sliderPos) {
      digitsSlider.value = sliderPos;
      digitsLabel.textContent = s.precision;
    }
    const wanted = s.rounding === 8 ? "round_truncate"
      : s.rounding === 1 ? "round_round" : "round_float";
    document.querySelectorAll('input[name="rounding"]').forEach((radio) => {
      radio.checked = radio.id === wanted;
    });
  } catch (err) {
    /* simulator not up yet - keep polling */
  }
}
setInterval(poll, 80);
poll();
