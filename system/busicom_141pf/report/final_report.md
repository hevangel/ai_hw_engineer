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

- **Print content under accelerated drums**: with `+spin` drum speedups the
  firmware's per-sector shifter setup gets tight; multi-character lines can
  smear across paper rows. `run_system_test.sh` uses +spin=740 (2× real
  drum speed) where single results print exactly; authentic timing
  (+spin=1481) is deterministic but slow in wall time.
- **Decimal-point switch**: the front-panel precision switch passes its
  value to the firmware, but printed decimal rendering at non-zero
  settings has not been tuned yet (default 0 prints integers).
- z3 remains the jammy apt version (4.8.12); SBY runs it fine.

## Tool notes for the next agent

- xezim 0.10.3: DPI calls cost ~0.2 ms wall each — never call per clock;
  keep testbench processes time-driven (`#delay`), never `@(posedge clk)`
  once a DPI import is in the build.
- xezim 0.10.3 rejects `import "DPI-C" function void f(...)` (parse error
  at the `)`): return `int` and ignore it.
- Debug `$display` output goes to stdout (redirect it), not the `-l` log,
  and is block-buffered while the sim runs.
