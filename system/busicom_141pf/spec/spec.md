# BUSICOM 141-PF — System Specification

A virtual-platform reconstruction of the **Busicom 141-PF** (1971), the first
commercial calculator built around a microprocessor (Intel 4004 / MCS-4
chip set). The hardware runs as RTL in the xezim simulator using the chip
designs from `design/intel_400{1,2,3,4}`, executes the **original 1280-byte
calculator firmware**, and talks to a web-app front panel over DPI-C.

Status: **working draft** — see `plans/implementation_plan.md` for build-out
sequence and `report/` for verification results.

## 1. Historical machine

| Item | Value |
|---|---|
| Product | BUSICOM 141-PF desktop printing calculator |
| Introduced | October 1971 (Nippon Calculating Machine Corp. / Busicom) |
| Significance | First commercial product powered by a microprocessor (Intel 4004) |
| CPU clock | ~740 kHz two-phase; 8 clocks per machine cycle (~10.8 µs/instruction) |
| Output | Shinshu Seiki (Epson) Model-102 impact drum printer — **no tube display** |
| Input | 32-key keyboard, decimal-point selector (0–8), rounding selector |

The 141-PF is a **printing** calculator: entries and results appear on the
paper roll as the drum printer types them. Typed digits are not shown until
an operator or `=` key forces a print.

## 2. Board composition

| Chip | Qty | Role in this reconstruction |
|---|---|---|
| intel_4004 | 1 | CPU (`design/intel_4004`) |
| intel_4001 | 5 | Mask ROM, 256 bytes each, CHIP_NO 0–4 (`design/intel_4001`) |
| intel_4002 | 2 | RAM, variant -1; RAM0 on CM-RAM line 0, RAM1 on line 1 (`design/intel_4002`) |
| intel_4003 | 3 | 10-bit shift registers (keyboard scan, printer ×2 cascaded) (`design/intel_4003`) |

Firmware: the original calculator mask contents, 5 × 256 bytes
(`src/rom/rom_4001_N.hex`, provenance in `spec/reference/`).

## 3. Board wiring (per peripheral bus)

All chips share the 4-bit data bus (open-drain style: exactly one `data_oe`
driver at a time), `sync`, `cm_rom`; the 4002s sit on separate CM-RAM lines.

### 3.1 ROM port I/O

| ROM port | Direction (IO_DIR) | Signal |
|---|---|---|
| ROM0 bit 0 | output | 4003 #0 and #1/#2 shift clock (active low pulse) |
| ROM0 bit 1 | output | serial data: ~bit for 4003 #0 (keyboard), bit for 4003 #1 (printer) |
| ROM0 bit 2 | output | shift clock for 4003 #1 and #2 (printer chain, active low) |
| ROM1 bits 3:0 | input | keyboard matrix column nibble |
| ROM2 bit 0 | input | printer drum index (one pulse per drum revolution) |
| ROM2 bit 3 | input | manual paper-advance button (front panel) |
| ROM2 bits 2:1, ROM3, ROM4 | — | unused, tied low |

4003 #2 is clocked from the same line as #1; its serial input is the
`so` (serial out) of 4003 #1 — a 20-bit printer shift chain.

### 3.2 RAM output ports

| RAM port | Bit | Signal |
|---|---|---|
| RAM0 (CM-RAM0) | 0 | print in **red** (per line, latch until line advance) |
| RAM0 | 1 | fire hammer (edge) |
| RAM0 | 3 | advance paper (edge) |
| RAM1 (CM-RAM1) | 0 | **Memory** lamp |
| RAM1 | 1 | **Overflow** lamp |
| RAM1 | 2 | **Negative** lamp |

### 3.3 CPU TEST pin

The printer drum rotation is timed by the CPU `TEST` input: it toggles every
drum half-spin, and the drum-index pulse (ROM2 bit 0) fires once per full
revolution. The firmware busy-waits on TEST (JTN/JNT) to sequence printing.

## 4. Front panel (modelled exactly)

### 4.1 Keyboard matrix

The firmware scans by shifting a one-hot through 4003 #0 (Q0…Q9 = rows).
A pressed key ties its column bit into the ROM1 port nibble. Rows 8/9 are
not keys but the two selector switches, read through the same matrix:

| Scan row (4003 #0) | Columns 1/2/4/8 (ROM1 bit0/1/2/3) |
|---|---|
| Q0 | CM, RM, M−, M+ |
| Q1 | √, %, M=−, M=+ |
| Q2 | ◇, ÷, ×, = |
| Q3 | −, +, (unused), 000 |
| Q4 | 9, 6, 3, . |
| Q5 | 8, 5, 2, 00 |
| Q6 | 7, 4, 1, 0 |
| Q7 | Sign, Exchange, CE, C |
| Q8 | returns decimal-point selector value (0–8) |
| Q9 | returns rounding selector (0 = float, 1 = round, 8 = truncate) |

Front-panel button (not scanned): Move Up = paper advance (ROM2 bit 3).

### 4.2 Printer model (Model-102 drum)

* 20-bit hammer word from the 4003 #1+#2 chain:
  * bits 3–17 → 15 numeric columns,
  * bit 0 → symbol column A, bit 1 → symbol column B, bit 2 unused.
* The drum has 13 positions per revolution; the character under the hammers
  at spin *n* is printed:

| Spin | Numeric cols | Symbol col A | Symbol col B |
|---|---|---|---|
| 0–9 | `0`–`9` | `◇ + − × ÷ M+ M- ^ = √` | `# * Ⅰ Ⅱ Ⅲ M+ M- T K E` |
| 10–11 | `.` | `%`, `C` | `Ex`, `C` |
| 12 | `-` | `R` | `M` |

* Hammer fires on the RAM0-bit1 rising edge, printing the current drum
  character into every selected column of the current paper line.
* Paper advance (RAM0-bit3 rising edge, or the Move Up button) shifts the
  7-line paper window up and starts a fresh line (clears the red latch).
* Pacing (virtual drum): one drum half-spin per 1481 machine cycles
  (≈16 ms at the authentic 92.5 kHz machine-cycle rate); index pulse every
  26 half-spins.

## 5. Virtual platform architecture

```
web app (browser)  ←— HTTP/JSON —→  panel bridge (C, pthread HTTP server
     ▲                               loaded into xezim via --dpi-lib)
     │ keys, switches                     ▲  keys/drum state      │ lamps,
     └────────────────────────────────────┘                       │ paper,
                                                                  ▼
DPI-C calls ←— tb_top.sv (clock/reset, machine-cycle pacing, TEST pin)
                  └── busicom_141pf.sv (board: 4004 + 5×4001 + 2×4002 + 3×4003
                                        + keyboard matrix + printer edge detect)
```

* The **hardware** (chips, bus, matrix, shift registers, edge detectors)
  is RTL under `src/`, simulated by xezim (`tb/tb_top.sv`).
* The **panel bridge** (`host/dpi/panel_bridge.c`) is a DPI-C shared
  library that also serves the web app: key state, selector switches,
  lamps, paper rows, drum window. One process, no external daemons.
* The **web app** (`host/web/`) replicates the real front panel: paper
  tape, drum window, keyboard, switches, lamps, Move Up button.

## 6. Verification plan

1. **Board smoke (headless)**: run the firmware without keys; assert the
   keyboard-scan shift register cycles and the drum index is consumed
   (firmware alive).
2. **End-to-end**: drive keys over HTTP (`1`, `+`, `2`, `=`) and assert the
   printed paper line contains `3.`-style output; repeat for `÷`, `%`,
   memory and rounding operations.
3. **Feature sweep**: all 32 keys produce a scanned code; each selector
   value is readable; lamps track overflow/memory/negative operations.
4. Non-goals: cycle-accurate printer hammer analog timing; key rollover.

## 7. Sources and attribution

* Original firmware reverse-engineering: B. & B. Silverman, E. Dvorak,
  L. Kintli — <https://www.4004.com> (Busicom 141-PF Replication Project,
  CC BY-NC-SA 2.5 for project materials). ROM contents:
  `spec/reference/rom_141pf_combined.bin`.
* Board wiring / printer / keyboard protocol reference (facts only, no code
  reused): V. Ilmer's Busicom 141-PF emulator —
  `spec/reference/{busicom,boards,chips}/` (GitHub: veniamin-ilmer),
  <https://veniamin-ilmer.github.io/emu/busicom/>.
* Machine history: IPSJ Computer Museum,
  <https://museum.ipsj.or.jp/en/heritage/Busicom_141-PF.html>; Vintage
  Calculators Web Museum, busicom_141-pf page.

Educational reconstruction; original hardware and firmware by Busicom/Intel.
