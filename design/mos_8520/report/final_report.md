# MOS 8520 report

Status: **digital 8520 implemented on the qualified 6526 core; nine
residual differences from MAME and Amiga-software qualification open**.
Measured on 2026-10-23 in `ai-hw-engineer:latest` (Verilator 5.052,
xezim 0.11.0): `scripts/run_all.sh` exits 0 in one fresh run.

## Reference and classification

MAME's `mos6526.cpp`/`.h` (BSD-3-Clause) are compiled unchanged against
project framework stubs (`tb/mame_stubs`, `tb/cia_oracle.cpp`); one call
is one `execute_run()` cycle, and the CPU access is applied before it.
Before relying on MAME for 8520 differences, the qualified `mos_6526` RTL
was compared with MAME's 6526 core (`tb/cia6526_compare.cpp`, recorded in
the [plan](../plans/implementation_plan.md)):

- stopped-timer high-byte writes: the RTL (agreeing with VICE) reloads the
  counter one cycle earlier than MAME;
- /IRQ assertion latency after an ICR flag differs in about 120 of
  2,000,000 random cycles, against both MAME 6526 and 6526A.

The 6526 keeps its VICE/Lorenz-qualified timing. For the 8520, MAME is the
only available reference and cites vAmigaTS hardware tests, so its reload
timing is adopted through an 8520-only timer parameter.

## Verification

- Strict Verilator `-Wall` lint passes.
- Random register traffic (all sixteen registers,
  CRA/CRB writes with force-load and one-shot bits) with a random-period
  TOD pin clock: **2,000,000 cycles, 333,701 reads**, every read, /IRQ and
  the 24-bit TOD counter compared each cycle. The TOD counter matches on
  every cycle. **Nine residual mismatches** remain (six single-cycle /IRQ
  edges, and three ICR reads where the RTL does not yet report a flag that
  MAME reports, causes not yet traced); the
  gate fails if they increase. The directed one-shot probe
  (`tb/cia8520_probe.cpp`) matches MAME cycle for cycle.
- The first **200,000** cycle records replay in **both Verilator and
  xezim**.
- The new TOD block's properties (comparator state, alarm source timing,
  register B, latch stability, stopped counter, divider) pass ABC BMC
  depth 20 and a k-induction proof (smtbmc/Yices; ABC PDR did not converge
  in five minutes on the 24-bit comparator); all **four covers** are
  reached by step 5 (counting, alarm, latched read, nibble ripple).
- Yosys synthesis and `check -assert`: **1,743 generic cells**.
- The shared `mos_6526_timer` gained two parameters that default off; the
  full `design/mos_6526/scripts/run_all.sh` (including all original
  Lorenz, Transactor, serial and TOD software) passes unchanged.

## Remaining qualification

The nine residual cases and the 6526/MAME classes need physical
captures. Original Amiga software (Kickstart and test programs) belongs to
the Amiga chip-set work, which is not part of the four requested systems.
