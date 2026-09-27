# Final Report — BUSICOM 141-PF virtual platform

## Status: working end-to-end

The reconstructed MCS-4 board (intel_4004 + 5×intel_4001 + 2×intel_4002 +
3×intel_4003 from `design/`) runs the **original 1971 calculator firmware**
(spec/reference). The web front panel drives keys and switches over HTTP
through the DPI panel bridge; printed output returns to the web paper tape.

Automated verification (`scripts/run_system_test.sh`) now checks exact totals
from the original firmware, using adding-machine entry (`+` after each
operand): `1 + 2 + =` → **3**, `5 + 6 + =` → **11**, `9 × 3 =` → **27**,
`14 + 29 + =` → **43**, and `9 + 3 − =` → **6**. The earlier test's
"any digit" multiplication check was insufficient to establish correctness.

The 2026-09-26 repairs connect the missing drum-index signal, capture the
current drum character, fix stale ROM hierarchy references, and correct the
4004's DAA/TCS semantics against an external oracle. CPU lint, ISA simulation,
formal BMC/prove/cover, and synthesis pass. See the
[failure note](../../../failure_notes/2026-09-26-busicom-printer-decimal-carry.md).

## What was verified

1. **Board bring-up (headless)**: firmware boots; the keyboard-scan one-hot
   sweeps all 10 matrix rows (`run_sim.sh` self-check).
2. **End-to-end (host bridge)**: HTTP-driven key sequences print results on
   the virtual paper tape (`run_system_test.sh`).
   On 2026-09-26 all five exact-total checks passed in xezim 0.10.5 and
   independently in Verilator 5.053. Precision-2 output `3.00` was also
   checked in Verilator. The board's `-Wall` lint has no errors; it retains
   unused-signal/parameter, empty-pin, and clock-initializer warnings.
   After restarting the live app, browser clicks `C`, `5`, `+`, `6`, `+`,
   `=` produced tape rows `0 C`, `5 +`, `6 +`, `11 *`; the busy indicator
   cleared and all keys were enabled afterward.
3. **intel_4004 FIN fix** (found by this system, see below): the 4004
   regression, formal (bmc/prove/cover with a corrected golden model),
   lint and synthesis all pass after the fix.

## Bug found in design/intel_4004: FIN program-counter advance

Running the original firmware showed every `FIN` skipping the instruction
after it. FIN is a **one-word** instruction executed over **two** cycles;
the design advanced the program counter by two (as for two-word
instructions), so the word following every FIN never executed. The Kintli
disassembly of the recovered firmware confirms code directly after FIN is
live (e.g. the FIM at $037 that loads the translate-table base).

Fix: `intel_4004.sv` advances PC by one for FIN; the TB's instruction-set
simulator was corrected identically, and the formal golden model in
`intel_4004_props.sv` was updated (FIN now excluded from the +2 advance).
All 4004 verification passes with the corrected semantics.

## Debugging techniques that worked (for future systems)

- **Reference harness**: rebuilding the vendor emulator's host loop in Rust
  against its own chip crate reproduced the stall identically to the RTL —
  proving the divergence was in shared *protocol* assumptions, then in the
  4004 itself.
- **Firmware disassembly** (4004.com, Kintli 1.0.1) as the authoritative
  contract: port nibble aliasing (SRC nibble mod 5), RAM strapping (both
  4002s on CM-RAM line 0, P0 straps 0/1), sector/index printer timing.

## Known issues / refinements

- **Startup**: the panel reports `ready: 0` and disables keys for the first
  2000 simulation ticks. Early HTTP key requests are held until ready.
  At idle, the simulation parks; a key press wakes it. The drum window
  shows the rotating print characters, while calculations print on the tape.
- **Historical timing observations below** predate the 2026-09-26 fixes.
  The supported regression configuration remains `spin=740`; do not infer
  current correctness for other simulator options from old runs.

- **Web panel busy indicator fixed (2026-09-26)**: drum cells now live in a
  table row. Previously, each status update threw when accessing the missing
  row, leaving the controls disabled after a click even when the bridge was
  idle. Verified in the running browser: a digit press enters busy, then clears
  the spinner and re-enables controls. See the
  [failure note](../../../failure_notes/2026-09-26-busicom-panel-busy.md).

- **Firmware key dispatch is drum-coupled (spin is NOT transparent)**:
  at the authentic `+spin=1481` the firmware's main-loop key dispatcher
  registers host key presses as garbage or misses them; at
  `+spin=740` presses register exactly (E2E-verified). The earlier
  assumption "all drum timings scale together, so firmware behaviour is
  unchanged" is false for the keyboard path — `run_system.sh` therefore
  defaults to spin=740. Beware: xezim 0.10.3 silently DROPS a `+plusarg`
  placed after `--dpi-lib` on its command line; keep plusargs before it
  (this bit us: the launch script looked like spin=740 but ran 1481).
- **xezim JIT/AOT on this board (retracted)**: an earlier note claimed
  `XEZIM_JIT=1 XEZIM_AOT=1` miscompiled this board (wrong E2E results).
  That report was withdrawn (xezim issue #153, closed 2026-09-05): with a
  deterministic stub bridge the interpreter and JIT produce byte-identical
  results. The wrong-results symptom was a wall-clock harness artifact
  (the pacing removed on 2026-09-25), not a simulator bug. JIT is safe to
  try; note the prebuilt binary must be compiled with `--features jit`
  (it is not in the default feature set).
- **Only ONE testbench process may call into the DPI bridge**: driving
  `dpi_panel_keys()` from a second, faster `#delay` process garbles the
  machine's view of key presses (lost presses, ghost keys). All bridge
  traffic rides the single drum-tick loop in `tb_top.sv`.
- **Print content under accelerated drums**: multi-character lines can
  smear across paper rows at 2× drum speed; single results print
  exactly (E2E asserts them).
- **Decimal-point switch**: the front-panel precision switch passes its
  value to the firmware, and printed decimal rendering at non-zero
  settings has been verified: the drum table emits "." at spins 10/11
  (matching the reference emulator), the precision path
  (/switches → dpi_panel_ctrl[3:0] → precision_i → firmware) is correct,
  and empirical testing with precision=2 confirmed "." prints on paper.
  (Default 0 prints integers.)
- Wall-time behaviour at the default settings: the interpreter simulates
  ~3.5k machine cycles/s on the reference host, ~14× slower than the
  16 ms/tick pacing target, so key echo takes ~1-3 s and a printed
  result ~10-20 s — faithful machine behaviour, slowed by simulation
  throughput, not by pacing.
- **Wall-clock pacing removed**: the `BUSICOM_PACE` option (sleeping
  ~16 ms inside every `dpi_panel_ctrl` call) correlated with dropped or
  garbled key registrations, and was pointless on the reference host
  anyway — the interpreter runs ~14x slower than real time with or
  without it. The pacing logic has been removed from `panel_bridge.c`.
- z3 remains the jammy apt version (4.8.12); SBY runs it fine.

## Tool notes for the next agent

- xezim 0.10.3: DPI calls cost ~0.2 ms wall each — never call per clock;
  keep testbench processes time-driven (`#delay`), never `@(posedge clk)`
  once a DPI import is in the build, and keep exactly one DPI-calling
  process (see known issues above).
- xezim 0.10.3 rejects `import "DPI-C" function void f(...)` (parse error
  at the `)`): return `int` and ignore it.
- `$display` output (TB and RTL) lands in the `-l` log file, and is
  block-buffered while the sim runs; stdout carries only the launcher's
  own prints.
