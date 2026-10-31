## What this does

Implements **review item P1** from #60: replace the uniform 5 ns placeholder delay
with per-part datasheet propagation delays, and add a regression at maximum-spec
delays.

The generated revision-0 board previously gave every 74LS package `T_PD(5ns)` and
the 4116 `T_PD(20ns)`. At 5 ns the board is effectively a zero-delay functional
simulation dressed in pins: the DRAM setup/hold margins and the RAS→CAS→data-latch
window were never exercised.

## How

* **`board/timing.json`** — typical and maximum delay for every modelled package,
  each with the manufacturer document, section, printed page and URL that publish
  it. 31 entries.
* **`generate_rev0.py --timing typ|max`** — regenerates the same connectivity from
  that table. A characterized entry without a source is a hard error, so a number
  cannot enter the board on trust. `--timing legacy` still reproduces the
  checked-in board byte for byte and stays the default, because the directed
  testbenches encode zero-delay phase relationships.
* **`scripts/run_timing_sim.sh`** — the datasheet gate: socket wiring at typical
  delays, Monitor boot at typical and maximum delays.
* Testbenches gain a 2000 time-unit settle window before the oscillator starts;
  delayed continuous assignments otherwise propagate X from the all-unknown
  time-zero state.

Two entries are **bounds, not board-load numbers**, and say so in the table: the
8T97 sheet is specified at CL = 50 pF (its 13 ns maximum is conservative at 15 pF),
and no Signetics 8T28 delay was readable, so the AMD second-source 17 ns maximum is
used. The DRAM and ROM models are marked `idealized` and keep the legacy delay in
every mode, because they have no access-time behaviour — giving them a datasheet
access delay is P3's rework, not a TTL delay question.

## Verification

Icarus 12.0-3 in the Apple II tools image, same authored CPU and unmodified Monitor
ROM in every row:

| Timing set | Directed socket test | Monitor keyboard/CPU | Monitor frame comparison |
|---|---|---|---|
| legacy (5 ns, checked in) | pass | pass, 64,393 instructions, 4,516 unresolved reads | pass, pixel-exact |
| datasheet typical | pass | pass, 64,394 instructions, 4,516 unresolved reads | rejected: scan state 25/256 where the oracle has 24/256 |
| datasheet maximum | fail: RAM row 0 read xx at 25.213729 ms | pass, 64,394 instructions, 4,516 unresolved reads | not compared by the gate |

* `generate_rev0.py --check` passes; the typ and max boards differ **only** in
  `T_PD` values (checked by normalizing both outputs).
* `run_lint.sh` passes; all four Verilator tops unchanged.
* `run_timing_sim.sh` exits 0 and its summary line names the two open comparisons.
* `run_authored_boot.sh` (legacy) passes, including the pixel-exact frame.

## Open, stated rather than hidden

1. `tb/tb_rev0_wiring.sv` drives address/data at the phi0 rising edge with fixed
   300/470 ns waits — a zero-setup, zero-delay stimulus. Its maximum-delay
   readback failure is therefore not evidence about the board yet.
2. `tb/tb_rev0_boot.sv` samples 10 ns after the pixel flip-flop clock, shorter than
   a 74LS74's 25 ns typical clock-to-Q, so the frame comparison is rejected at any
   non-zero delay.

Both are recorded in `report/final_report.md` and in the gate's own summary.

Also fixes **C6** from #60: the duplicated "Physical package adapter" section in
`design/mos_6502_cycle/spec/spec.md`.

## Provenance note

Values were read from the manufacturer PDFs; the TI literature number is recorded
only where the scan prints one (13 of 24 LS parts). The rest cite document URL and
printed page. One part, 74LS161, comes from the Fairchild DM74LS161A sheet because
it has no readable TI switching table; its maximum is used for both modes since
Fairchild publishes no typical column. 74LS257 (Signetics) is the same.

Refs #60.
