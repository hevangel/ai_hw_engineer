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
for (let c = 0; c < PAPER_COLS; c++) {
  const td = document.createElement("td");
  td.textContent = " ";
  drumTable.appendChild(td);
}

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
  if (busy === b) return;
  busy = b;
  busyEl.hidden = !b;
  keyBtns.forEach((btn) => { btn.disabled = b; });
  advanceBtn.disabled = b;
  document.body.classList.toggle("is-busy", b);
}

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
digitsSlider.addEventListener("input", () => {
  digitsLabel.textContent = digitsSlider.value;
  post("/switches", { precision: parseInt(digitsSlider.value, 10) });
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
    setLed("led_memory", s.lamps.memory, "memory");
    setLed("led_overflow", s.lamps.overflow, "overflow");
    setLed("led_negative", s.lamps.negative, "negative");

    /* the bridge clears busy when the 4004 is idle again */
    setBusy(!!s.busy);

    if (parseInt(digitsSlider.value, 10) !== s.precision) {
      digitsSlider.value = s.precision;
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
