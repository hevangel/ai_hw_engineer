# Final Report — BUSICOM 141-PF virtual platform

## Status: working end-to-end

The reconstructed MCS-4 board (intel_4004 + 5×intel_4001 + 2×intel_4002 +
3×intel_4003 from `design/`) runs the **original 1971 calculator firmware**
(spec/reference). The web front panel drives keys and switches over HTTP
through the DPI panel bridge; printed output returns to the web paper tape.

Automated verification (`scripts/run_system_test.sh`): 1 + 2 = prints
**3**; 9 × 3 = prints the product digits. Rebuilt image sanity gate and all
eight chip-design flows (lint/sim/formal/synth) pass on the updated
toolchain.

## What was verified

1. **Board bring-up (headless)**: firmware boots; the keyboard-scan one-hot
   sweeps all 10 matrix rows (`run_sim.sh` self-check).
2. **End-to-end (host bridge)**: HTTP-driven key sequences print results on
   the virtual paper tape (`run_system_test.sh`).
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

- **Firmware key dispatch is drum-coupled (spin is NOT transparent)**:
  at the authentic `+spin=1481` the firmware's main-loop key dispatcher
  registers host key presses as garbage or misses them; at
  `+spin=740` presses register exactly (E2E-verified). The earlier
  assumption "all drum timings scale together, so firmware behaviour is
  unchanged" is false for the keyboard path — `run_system.sh` therefore
  defaults to spin=740. Beware: xezim 0.10.3 silently DROPS a `+plusarg`
  placed after `--dpi-lib` on its command line; keep plusargs before it
  (this bit us: the launch script looked like spin=740 but ran 1481).
- **xezim 0.10.3 JIT/AOT miscompiles this board**: with
  `XEZIM_JIT=1 XEZIM_AOT=1 XEZIM_PROC_FSM=1` the E2E prints wrong
  results (interpreter is correct; speedup was only ~25% anyway). Do
  not enable those for this design until an upstream fix.
- **Only ONE testbench process may call into the DPI bridge**: driving
  `dpi_panel_keys()` from a second, faster `#delay` process garbles the
  machine's view of key presses (lost presses, ghost keys). All bridge
  traffic rides the single drum-tick loop in `tb_top.sv`.
- **Print content under accelerated drums**: multi-character lines can
  smear across paper rows at 2× drum speed; single results print
  exactly (E2E asserts them).
- **Decimal-point switch**: the front-panel precision switch passes its
  value to the firmware, but printed decimal rendering at non-zero
  settings has not been tuned yet (default 0 prints integers).
- Wall-time behaviour at the default settings: the interpreter simulates
  ~3.5k machine cycles/s on the reference host, ~14× slower than the
  16 ms/tick pacing target, so key echo takes ~1-3 s and a printed
  result ~10-20 s — faithful machine behaviour, slowed by simulation
  throughput, not by pacing.
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
