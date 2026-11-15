# MC146818 implementation plan

1. **Sources.** Obtain the MC146818 data sheet ADI-856-R1 (1983 data
   book) and the earlier 1981 printing, and record their differences. Take
   the AT's CMOS map and BIOS access sequences from the IBM PC AT
   Technical Reference. Use MAME only as a behavior cross-check.
2. **Reference model first.** Write `scripts/mc146818_model.py` from the data
   sheet alone: atomic bus operations, one tick per oscillator period, and
   the calendar arithmetic as a pure function (`update_time`). Check the
   arithmetic against Python `datetime` (`check_calendar.py`).
3. **Directed tests.** Write `scripts/directed_tests.py` with literal expected
   values worked out by hand from the data sheet tables and the assumption
   ledger. They must pass on the model before any RTL comparison.
4. **RTL.** Write one module, `src/motorola_mc146818.sv`, with these parts:
   - a 64-byte array holding the time bytes, A and B, the C flags and VRT,
     with the next state computed combinationally and registered on `clk`;
   - strobe edge detection on sampled AS/DS, and the register C double
     latch;
   - a 22-bit divider counting 4.194304 MHz periods, so that the RS taps are
     absolute bit positions;
   - a three-state update sequencer (idle, tBUC, tUC) with a period counter;
   - a combinational calendar increment, DST and alarm compare;
   - inline `ifdef FORMAL` properties.
5. **Lockstep bench.** Write `tb/mc146818_tb.cpp`, which drives the pins from
   the same script format as the model and writes a trace. That trace must
   equal the model's: every read value, IRQ/SQW after every command, every
   IRQ/SQW change during ticks, and full dumps.
6. **Random and coverage.** Write `gen_random_test.py` (32 seeds,
   FAST_SHIFT 6) and `report_coverage.py`, which gates on the registers,
   bits, interrupt sources and rollovers exercised.
7. **Real software.** Write `bios_replay.py`, which replays the AT BIOS
   port 70h/71h sequences through the board adapter, for a cold boot with a
   dead battery and a boot with a valid configuration image. It then
   applies the listing's own branch decisions to the RTL's read values.
8. **Formal, mutation and synthesis.** Write `formal/motorola_mc146818.sby`
   (abc pdr proof, smtbmc yices cover), `run_mutation.sh` (six planted
   faults), and `run_synth.sh` (Yosys `synth`, `check -assert`, latch
   grep).
9. **Documentation and index.** Write the README, the spec with its
   assumption ledger, the report, and the `design/README.md` row.
