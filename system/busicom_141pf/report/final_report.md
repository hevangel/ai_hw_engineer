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
formal BMC/prove/cover, and synthesis pass. See the [FIN failure note](../../../failure_notes/2026-09-02-intel4004-fin-pc-advance.md)
and [manual-regression failure note](../../../failure_notes/2026-09-27-busicom-manual-regression.md).

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

## Current status (2026-09-27)

The earlier five-case results above are historical. The full 42-example manual
regression, updated toolchain, and independently confirmed differences are in
[manual_regression.md](manual_regression.md). The manual is now available as
[readable Markdown](../spec/reference/Unicom_141P_manual.md) and
[replay JSON](../spec/reference/Unicom_141P_examples.json).

The follow-up found remaining keyboard polarity, printer index/phase, TCS and
DAA defects. These are corrected; see the
[failure note](../../../failure_notes/2026-09-27-busicom-manual-regression.md).
The authentic `spin=1481` now reproduces the recovered ROM's results across all
42 examples on Verilator 5.052. The earlier claim that this rate necessarily
corrupts keyboard input is superseded by that evidence. `run_system.sh` defaults
to 1481 and supports `BUSICOM_BACKEND=xezim` or `verilator`.

### Web panel (2026-09-29)

The current panel shows the calculator, built-in manual replay and a collapsible
Surfer waveform view. Each panel has an independent minimize control; the
calculator help button is at the upper left. Verilator captures each key or
paper-advance operation as FST with the 4004 interface ports in the default
Surfer signal list. See the [system README](../README.md) and its current
[screenshot](../assets/web-app.jpg). This UI update does not change the
historical regression results above.

### Operational limits

- Startup retains a 2000-tick firmware initialization interval. Keys are disabled
  until `ready` becomes true. Wall time depends on simulator throughput.
- The simulation currently continues running while idle; the bridge's optional
  parking functions are not called by this testbench.
- Only one testbench process may advance the DPI key presenter. HTTP replay
  clients must run one at a time for a given panel.
- Drum characters rotate independently of the printed tape. For addition, use
  `5 + 6 + =`; the second plus enters the second amount in the accumulator.
- The manual's buffer/capacity prose is transcribed, but input-buffer timing and
  physical paper/ribbon procedures are outside the numbered-example regression.
- Five scan/ROM differences are explicit profiles, not changes to the original
  printed expectations. See the current regression report before interpreting
  a strict-manual failure.

### Simulator notes

The old xezim JIT/AOT miscompile allegation was retracted (upstream issue #153).
The Docker build enables the `jit` feature. Set `XEZIM_JIT=1 XEZIM_AOT=1` when
launching xezim to use native compilation. The current build is xezim 0.11.0.
The simulator time limit is explicit in the launch script. Keep plusargs before
`--dpi-lib` for compatibility with older xezim launchers. `$display` output is in
the simulator log, which may be buffered while it runs.

Tool pins, source links and update exceptions are recorded in
[toolchain-releases.md](../../../docs/toolchain-releases.md).
