**Status on P1 (package timing) and C6**

Working through the suggested priorities, starting with P1.

**What changed** (uncommitted in the working tree)

- `system/apple_ii/board/timing.json` — a per-part typical/max propagation delay for every modelled package, each with the datasheet, document number, page and URL that publish it. 26 sourced parts (24 LS devices, 8T28, 8T97), read from the worst TYP/MAX row of the switching table at VCC = 5 V, CL = 15 pF, 25 °C. Parts that publish only min/max use the maximum for the typical run; that and the one fractional value (74LS51, 12.5 → 13 ns) are recorded in the generated metadata.
- `generate_rev0.py --timing legacy|typ|max` — same connectivity and same generated RTL shape, selectable delay set. `legacy` reproduces the checked-in board byte-for-byte. Unknown parts, uncited values and missing typicals fail closed.
- `scripts/run_timing_sim.sh` — reruns the socket and Monitor gates at datasheet delays.
- Testbenches: a 2 µs static settle before the oscillator starts. At 30–40 ns delays the all-X time-zero state no longer resolves before the first clock edge and the board clock fails to start; silicon has no equivalent X state.
- C6: removed the verbatim duplicate "Physical package adapter" section in `design/mos_6502_cycle/spec/spec.md`.

**Measured** (Icarus 12.0-3, same authored CPU and unmodified Monitor ROM in every row)

| Timing set | Socket test | Monitor keyboard/CPU | Frame comparison |
|---|---|---|---|
| legacy 5 ns (checked in) | pass | pass, 64,393 instr, 4,516 unresolved reads | pixel-exact, 107,520 samples |
| datasheet typical | pass | pass, 64,394 instr, 4,516 unresolved reads | rejected: sync mismatch at line 0 sample 0 |
| datasheet maximum | fail, readback X | pass, 64,394 instr, 4,516 unresolved reads | rejected: scan state 25/256 at line 0 sample 0 |

The load-bearing result: the unmodified Monitor completes its keyboard, deposit, examine and readback path with every TTL package at published worst-case delay.

The two failures are harness assumptions, not board findings:

1. `tb_rev0_wiring.sv` changes address and data exactly at the phi0 rising edge and samples with fixed 300 ns / 470 ns waits — a zero-setup, zero-delay stimulus. That is one candidate cause of the maximum-delay readback failure; it has not been reduced to a specific model error.
2. `tb_rev0_boot.sv` samples 10 ns after the pixel flip-flop clock, shorter than the 25 ns typical clock-to-Q of a 74LS74, so the captured frame is offset at typical and maximum delays.

**P3 evidence.** A datasheet 4116 access delay makes the video data latch capture Hi-Z between CAS cycles: the model has no tRAC/tCAC or output-hold behaviour. The memory entries are therefore marked `idealized` with their published values recorded for that rework, and `run_all.sh` keeps legacy timing.

Evidence and the exact open items are in `system/apple_ii/report/final_report.md` ("Package timing", 29 October 2026) and `system/apple_ii/board/README.md#package-timing`.

Still open: S1, S2, S3, S4/S5, C1–C5, P2, P3.
