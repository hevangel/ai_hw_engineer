# MOS 6532 validation report

Validated 2026-10-18 using the existing `ai-hw-engineer:latest` container.
The digital contract is implemented and locally verified. Physical-chip
equivalence and Atari software integration are not established.

## Results

| Gate | Result |
|---|---|
| Verilator `--lint-only -Wall` | PASS, no RTL warning suppressions |
| Testbench lint | PASS; only mixed RTL/TB timescale warning suppressed |
| Formal BMC | PASS, 16 steps |
| Formal unbounded proof | PASS, ABC PDR |
| Formal cover | PASS, all five goals reached within four steps |
| Verilator complete regression | PASS, 71,622,900 checks, 1,024 timer cases |
| xezim representative regression | PASS, 682,848 checks, 20 timer cases |
| Yosys generic synthesis/check | PASS, 3,717 mapped cells, zero reported problems |

Tools: Verilator 5.052 (2026-09-05), Yosys 0.69 (`9f75ca1f9`), SBY v0.69,
xezim 0.11.0 (`6558a1e`). Generic cells include 1,024 RAM storage bits;
the result is not an FPGA area estimate or a timing closure claim.

## What was checked

The regression writes and reads complementary patterns across all 128 RAM
addresses, checks retention over reset and deselected writes, exercises all
256 DDR values per port, distinguishes PA pin readback from PB latch
readback under conflicting levels, and checks all port read/write aliases,
edge-control write aliases and flag-read aliases.

The complete timer sweep covers every load from 0 through 255 for /1, /8,
/64 and /1024. Expected counts come from elapsed time and the manufacturer's
N*P+1 expiry equation, rather than copying the RTL prescaler. Each simulated
clock checks both count and IRQ through expiry and two fast ticks. xezim
uses loads 0, 1, 2, 52 and 255 at each rate, plus the same other tests.

Directed cases exercise masked capture, both PA7 polarities, pending-event
enable, output-mode PA7, simultaneous flags, acknowledgment independence,
new-edge/acknowledgment priority, coincident timer-read/expiry, fast wrap,
prescaler restoration after acknowledgment, and high timer-write mirrors.

Formal properties prove register write/isolation/reset behavior, all four
prescaler reload values and divider transitions, timer state updates,
interrupt enable/flag updates, read/IRQ gating and arbitrary-address RAM
write/retention (`anyconst`). Covers reach RAM write/read, enabled timer
expiry, masked timer expiry, enabled PA7 interrupt and both flags together.
They verify the chosen contract, not its fidelity to unknown silicon details.

## Reproduction

From a POSIX shell with the image installed:

```sh
docker run --rm -v "$PWD:/workspace" -w /workspace --entrypoint sh \
  ai-hw-engineer:latest design/mos_6532/scripts/run_all.sh
```

Generated logs, formal witnesses, simulator binaries and synthesis JSON live
under `work/` and are ignored. The authored testbench uses `$fatal` and each
simulation script additionally requires its PASS marker, so a time limit
without completion cannot count as success.

## Limits and next step

The [specification](../spec/spec.md) records the assumptions: sampled PA7,
deterministic reset timer state and MAME-supported post-acknowledgment
prescaler restart. Subcycle edge capture, reset/polarity-change glitches,
electrical port drive and transistor behavior are not modeled. The board
must provide resolved PA pin inputs, pull-ups and open-drain IRQ combination.
Real Atari software and independent physical-chip traces remain integration
gates. The chip's exact introduction year is still unconfirmed.

The [series ledger](../../../plans/mos_historical_series.md) queues the 6522
next. All four requested complete systems remain unimplemented.
