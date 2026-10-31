# MOS 6522 VIA progress and validation report

Complete sampled-digital flow passed on 2026-10-18; results inspected after
the usage-limit interruption on 2026-10-19. The implementation is useful
progress toward the requested chip/system series, but full NMOS fidelity
and historical-system integration remain incomplete.

## Measured results

| Gate | Result |
|---|---|
| Verilator RTL `--lint-only -Wall` | PASS, no warning suppressions |
| Testbench lint | PASS; only mixed RTL/TB timescale warning suppressed |
| Formal BMC | PASS, 20 steps |
| Formal unbounded proof | PASS, ABC PDR |
| Formal covers | PASS, all ten goals reachable within 24 steps |
| Verilator regression | PASS, 3,506,569 checks; 131,072 timer-load cases; 1,792 serial streams |
| xezim representative regression | PASS, 590,620 checks; 1,024 timer-load cases; 32 serial streams |
| Yosys synthesis/check | PASS, 933 generic mapped cells, zero reported problems |

Toolchain: Verilator 5.052, Yosys 0.69 (`9f75ca1f9`), SBY v0.69,
xezim 0.11.0 (`6558a1e`), existing `ai-hw-engineer:latest` image.

## Verification scope

Every load value 0..65535 is checked on both timer counters for initial
readback, the first held clock and the subsequent decrement. This is not
an exhaustive deadline test for every load: exact interrupt deadlines are
checked for all byte loads and selected 16-bit boundaries, with formal
transition proofs covering arbitrary counters. Larger boundary cases also
check suppression of subsequent one-shot interrupts across a full wrap.
T1 free-run periods/PB7, latch-only writes, T2 pulse counting with low-byte
borrow and shared T2/serial counter arithmetic are checked separately.

Control tests cover all DDR masks, all IER masks/set-clear operations and
all 256 PCR words. Directed cases exercise both interrupt polarities,
independent-input acknowledgment, disabled-but-pending flags, new-event/
clear priority, no-handshake ORA, latch capture/freeze/release, PA/PB
readback differences, CA2/CB2 handshake and one-cycle pulse behavior.

Serial tests check actual MSB-first output pins and externally specified
input bytes. Modes 2/3/6/7 cover all byte patterns; modes 1/4/5 cover every
T2 low-byte divisor. Tests include repeated external groups, continuous
output without SR interrupt, clock intervals, finite-clock parking while
T2 continues counting, pin ownership and SR-read retriggering. xezim runs
the same bench with representative byte/divisor/load values.

Formal properties check reset/register isolation, IER set/clear, flag
event/clear priority, read/IRQ/port mapping, counter load/decrement/reload
and SR transitions. Ten covers reach all seven enabled IRQ sources,
handshake and pulse outputs, and a completed internal serial output.

## Reproduction and authoritative artifacts

```sh
docker run --rm -v "$PWD:/workspace" -w /workspace --entrypoint sh \
  ai-hw-engineer:latest design/mos_6522/scripts/run_all.sh
```

Ignored `work/` contains logs, witnesses, binaries and synthesis JSON.
Both simulations must produce their PASS marker; a timeout cannot pass.
Counters in the PASS line describe executed cases rather than inferred
coverage. No UVM test or physical-hardware comparison is claimed.

## Remaining requirements

The [specification's discrepancy ledger](../spec/spec.md) retains open
requirements: half-cycle IRQ onset, asynchronous sampling latency, NMOS
serial lost-edge behavior, IER7 readback, one-shot counter reload, repeated
input-latch edges, mid-transfer SR access/mode changes and mixed PB6/serial
clock ownership. Deterministic counter/SR reset contents are a modeling
assumption. The present self-authored bench cannot resolve contradictory
source evidence. Independent traces and authentic software integration
remain required before final chip/system sign-off.

The complete MOS and four-system objective remains active. Next initial
implementation is the 6530 RRIOT; pending VIA fidelity work remains in the
[series ledger](../../../plans/mos_historical_series.md).
