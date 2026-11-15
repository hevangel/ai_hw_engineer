# Motorola MC146818 verification report: 2026-11-14

## Result

The RTL (`src/motorola_mc146818.sv`) matches the reference model on every
trace line in every test. The model is `scripts/mc146818_model.py`, written
from data sheet ADI-856-R1 before the RTL. The trace lines are every bus
read, IRQ and SQW after every operation and at every change during ticks,
and full 64-byte dumps. The tests cover:
- 46 directed tests with literal expected values derived by hand from the
  data sheet;
- 32 random seeds;
- the IBM PC AT BIOS port 70h/71h access sequences, for a cold boot with a
  dead battery and a boot with a valid configuration.

In the BIOS replays, the chip satisfies every decision of the listed BIOS
code. The first access, OUT 70h,8Bh at F000:01AF then IN 71h, returns
register B. The POST checkpoint 02 rolling-bit test of shutdown byte 0Fh
passes all 9 passes. The battery check follows the expected branch for
each image. The configuration checksum matches. SET_TOD's UIP wait ends,
and its 59h/59h/23h limits hold.

All commands ran in the `ai-hw-engineer:latest` image (Verilator 5.052,
Yosys 0.69, SBY with abc pdr and yices, Python 3.14.4).

| Gate | Command | Result |
|---|---|---|
| Lint | `scripts/run_lint.sh` | `verilator --lint-only -Wall` clean for FAST_SHIFT 0 and 6, no waivers |
| Formal proof | `scripts/run_formal.sh` | abc pdr: PASS (unbounded), 2.9 s |
| Formal cover | `scripts/run_formal.sh` | 6 of 6 reached (steps 3, 5, 5, 18, 19, 20); smtbmc yices |
| Calendar vs `datetime` | `scripts/run_sim.sh` | 19,997 instants (10,000 near month ends) x 4 modes, all equal; alarm match/don't-care/miss checks pass |
| Directed tests | `scripts/run_sim.sh` | 46 of 46: the model meets every hand-derived expectation; RTL trace identical |
| Random sequences | `scripts/run_sim.sh` | 32 seeds x 1,500 operations, FAST_SHIFT 6: 494,702 trace lines identical; 1,998,309 ticks = 3,902 simulated seconds |
| Coverage gate (random) | `scripts/report_coverage.py --require` | 64/64 locations written and read; all 1,024 location.bit=value write combinations; all 15 RS rates; all three sources set flags (PF 152,063, AF 218, UF 2,285) and drove IRQ; rollovers: second 492, minute 381, day 175, month 118, year 41, century 0 (directed only), AM to PM 1, PM to AM 80, reaching Feb 29 3, leap-day end 14, common Feb 28 12, DST spring 1, DST fall 1; SET aborts 131; writes lost in tUC 1,282 |
| IBM AT BIOS, cold boot (all-zero image) | `scripts/run_sim.sh` | C10A reads B = 00, C = 00. Checkpoint 02: 01..80, 00 all equal (no HLT). Checkpoint 16 reads D = 00, which takes the CMOS1A path, and BAD_BAT is written to 0Eh. The second read of D returns 80h. INITIALIZE_STATUS, INT 1Ah time set and a midnight/new-year rollover follow. EVENT_WAIT PIE gives IRQ 8 every 32 ticks (976.6 us), which RTC_INT's read of C (C0h) releases |
| IBM AT BIOS, valid configuration (`tb/nvram/at_cmos_valid.hex`) | `scripts/run_sim.sh` | C7B shutdown read. C10A reads B = 02. Checkpoint 02 passes. VRT = 1. The CMOS2 sum of 10h-2Dh (00C3h) equals 2Eh:2Fh. SET_TOD: UIP cleared after 74 polls of register A; time 12:34:57 is within limits |
| Mutation check | `scripts/run_mutation.sh` | 6 of 6 mutants killed by a trace difference (details below) |
| Synthesis | `scripts/run_synth.sh` | Yosys `synth` + `check -assert` clean: 3,960 generic cells, 556 flip-flops (512 hold the 64 bytes, minus the constant bits Yosys removed); no `Latch inferred` |
| Whole flow | `scripts/run_all.sh` | PASS in 358 s from a clean work directory (everything but `work/refs` removed first); most of the time is the mutation check's 18 bench builds |

## Independence of the reference model

The model was written from the data sheet's text and tables before the RTL.
Its page references are in its comments. Behavior the data sheet does not
state is tagged R1-R16 in the [assumption ledger](../spec/spec.md#assumptions),
with the same tags in the RTL. Two checks do not depend on the model:
- The calendar function is checked against Python's `datetime`.
- The directed tests carry literal expected values. Each test's comments
  give the data-sheet basis. While the tests were written, nine expectations
  first disagreed with the model. Each was traced to an omission in the
  hand derivation, not to the model: PF running with RS = 6 in the setup,
  UF set by every update, AF at 00:00:00 with zero alarm bytes, a PF
  already pending when PIE was enabled, and one tick-count error. The
  expectations were corrected to what the data sheet requires.

## Mutation check

Each mutant is a one-line change to a copy of the RTL. It is run through the
directed tests, 4 random seeds and the BIOS replays, without the coverage
gate. It must produce a trace difference.

| Mutant | Fault | First failing test |
|---|---|---|
| m1 | Register C read does not clear PF | `periodic_rates_32k` |
| m2 | BCD leap-year test ignores the tens digit | `roll_bcd_leap_feb28` |
| m3 | SET going high does not clear UIE | `registers_power_on` |
| m4 | tBUC = 7 instead of 8 periods | `update_cycle_timing` |
| m5 | Minutes alarm don't-care decoded from bit 7 only | `alarm_interrupts` |
| m6 | RESET pin does not clear SQWE | `reset_pin` |

The formal proof is not vacuous either. With m1 and m6 applied, `sby prove`
fails on the register C clear-on-read assertion at step 7.

## Findings in the sources

- **DS81 vs DS (1981 vs 1983 printing).** DS81 places the interrupt flags and
  their clear-on-read in "Register A" in its interrupt section, and swaps
  tUC and tBUC in the Figure 16 legend. DS corrects both. See the
  [spec](../spec/spec.md#ds81-vs-ds).
- **DS internal inconsistencies.** The update lockout is "1948 us" on
  p.3-710 but 1984 us in Table 6. "1.048567 MHz" is a typo. The statistics
  quote "4032" and "2032" attempts. This design follows Table 6.
- **MAME differences.** MAME does not abort a pending update when SET is
  written; DS p.3-714 says it does. MAME accepts writes during the update
  cycle; DS says the bytes are off the bus. MAME does not implement DSE.
  MAME sets VRT whenever it loads NVRAM.
- **IBM usage.** The Technical Reference calls VRT "VRB" and describes the
  flags as affected only when enabled. In DS the flags set regardless of
  the enables. The BIOS treats the time bytes as BCD 24-hour (SET_TOD
  limits), consistent with B = 02h.

## Limitations

- Only the Motorola mode of MOTEL is implemented. CKOUT/CKFS, the oscillator,
  electrical and bus AC timing, power-down/battery switchover and the
  date-code CE/AS addendum are not modeled.
- The data sheet's "undefined" reads during the update cycle return defined
  values (R5). DST and month-end changes do not need the time to be set two
  seconds in advance (R10).
- The real-software check replays the BIOS listing's port access sequences
  and decisions through the board adapter. It does not execute the AT BIOS
  on an 80286 model. That happens when the chip is integrated into
  `system/ibm_pc_at_5170`.
- The lockstep bench never coincides a tick with a bus cycle (the model is
  atomic). Concurrent tick/bus behavior (R1, R5 same-clock priority, the
  register C double latch) is covered by the formal properties only.
- Calendar rollovers with BCD 12-hour AM to PM appear once in the random
  runs. The directed tests cover each transition explicitly.
