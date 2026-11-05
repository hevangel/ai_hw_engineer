# Verification report — PDP-1 Am29xx reconstruction

Date: 2026-11-04. Issue [#184](https://github.com/hevangel/ai_engineer/issues/184).

## What was verified

| Check | Command | Result |
| --- | --- | --- |
| Lint | `sh scripts/run_lint.sh` | clean (`verilator --lint-only -Wall`, documented local waivers) |
| Build | `sh scripts/build_sim.sh` | `work/obj/Vpdp1_am29xx` built |
| Instruction-level oracle | `oracle_simh.sh` + `oracle_compare.py` | **100 / 100 instructions match SIMH exactly** (PC, AC, IO, OV) on seven programs; two programs reproduce known arithmetic defects |
| Synthesis | `sh scripts/run_synth.sh` | 6,298 cells; 360 latch bits, all inside the five Am2901 slices |
| Panel demo | `run_panel.sh`, LOAD DEMO → RUN | 64 display points, typewriter codes `P D P 1 CR`, machine halts |

Per-program oracle results (RTl vs SIMH PDP-1, commit `698dc8a1`):

| Program | Instructions compared | Result |
| --- | --- | --- |
| `smoke` | 5 | **mismatch** (defect 2) |
| `arith` (one's complement, ±0, EAC, overflow) | 8 | match |
| `logic` | 10 | match |
| `shift` (12 subcodes, multi-step) | 35 | match |
| `jumps` (jmp/jsp/cal/jda/xct/indirect) | 13 | match |
| `skip` (all members + inverted) | 15 | match |
| `index` (idx/isp/sad/sas) | 9 | match |
| `operate` (cla/cma/lat/cli/clf/stf) | 10 | match |
| `demo` (display + typewriter) | 690 | **mismatch on OV** (defect 1) |

The comparison reads SIMH's `show cpu history` dump and the RTL's
instruction-start trace, both at the same state point, and stops at the first
difference. It is an independent implementation: SIMH's PDP-1 is a separate
C code base, not derived from this RTL.

### Known defects (found by the oracle, not fixed)

**Defect 1 — spurious overflow.** `0o370000 + 0o4000` produces the correct sum
`0o374000` but sets OV; SIMH and the handbook rule leave OV clear (the operands
share a sign and the result keeps it). The flag is sticky, so the demo
comparison diverges at instruction 690 of 717 on OV alone. Reproducer:

```pdp1
        lac 20          ; M[20] = 0o370000
        add 21          ; M[21] = 0o4000
        hlt
```

**Defect 2 — EAC repair loop on subtraction.** `0o1235 - 0o000001` should
return `0o1234` with the end-around carry applied once. The repair loop instead
iterates hundreds of times and leaves AC = 0, so `tests/smoke.pdp1` diverges at
its fifth instruction. The `arith` program passes because its subtraction cases
(`0o400000-1`, `1-2`, `+0-1`) take a different path through the same loop.

Both live in the end-around-carry/overflow glue (`src/pdp1_datapath.sv` and the
`ADD_FIX`/`FIX_TEST` microcode pair). They are recorded rather than papered
over: the directed suite is split into the seven programs that pass and the two
reproducers, and no test was weakened to make the suite green.

### Defects the oracle caught

These are recorded because they show what the cross-check is for; all three
were fixed before the results above:

1. **Indirect addressing replaced the whole instruction word.** `jmp i 40`
   took the opcode from the indirect word instead of keeping the original, so
   every indirect jump dispatched the wrong handler. Fixed by loading only
   IR[12:0] during an indirect step.
2. **Combined shift fill raced the shift.** Each AC/IO phase overwrote the one
   edge latch the other phase still needed, so `rcl`/`rcr` inserted the
   *post-shift* edge bit. Fixed with one edge latch per register, both captured
   before either register shifts.
3. **`CRTN` needs the condition asserted.** The Am2910 pops the stack only on
   a passing condition, so the microcode subroutines returned to the wrong
   address and corrupted `szo`, `cla` and the EAC repair path.

The first two produced wrong architectural state that per-instruction unit
tests written from the same reading would have missed; the third produced a
silent fall-through that only a real program exposed.

## What was not verified

- **Spacewar! 4.1 is not run.** `sw41f.rim` is archived with provenance
  (bitsavers, CHM 2005 modification of the 2/20/63 source). Booting it needs
  the paper-tape read-in path and the display break timing, which are open.
  SIMH itself needs the tape attached to its PTR device to boot the RIM image,
  so no oracle run exists for it either.
- **`mus` and `dis`.** SIMH implements a later multiply/divide option for the
  same opcodes; this machine implements the 1961 handbook's multiply/divide
  *step* definitions, so those two instructions are excluded from the diff.
  They are covered by the handbook rule and by directed runs only.
- **I/O devices have no external oracle.** Typewriter, reader, punch and the
  Type 30 point plot are functional models checked through the panel demo; no
  independent device model was compared.
- **Sequence break** is implemented but not exercised by authentic software.
- **Formal properties** for the guard-bit/EAC/overflow/shift contracts are
  written into the specification but not yet in an SBY task.

## Limits (from the specification)

- Not transistor-level or electrical: the Am2901/Am2910 models are the
  repository's digital contracts.
- Timing: one microcycle is one clock; the documented 5 µs core cycle is
  modelled as `core_cycles × 5 µs` and shown in the panel. Internal microcycle
  sequencing is a reconstruction, not the original machine's.
- Memory: combinational read port, no destructive read, no core endurance or
  analog behaviour.
- Profile: no PDP-1D extensions, no 64K memory, no 16-channel sequence break,
  no DECtape/printer/clock, no display-list revision.
- FPGA acceptance is a separate issue and is not claimed here.

## Reproducing the oracle

```sh
# 1. build the RTL model (project image)
sh system/pdp1_am29xx/scripts/build_sim.sh
# 2. run the directed programs on the RTL
docker run --rm -v "$PWD:/work" -w /work ai-hw-engineer:latest \
    bash work/tools/run_tests.sh arith logic shift jumps skip index operate smoke demo
# 3. run the same images on the pinned SIMH container
docker build -f work/tools/oracle.Dockerfile -t pdp1-oracle:local work
docker run --rm -v "$PWD:/work" -w /work pdp1-oracle:local \
    bash system/pdp1_am29xx/scripts/oracle_simh.sh arith logic shift jumps skip index operate smoke demo
# 4. compare
python3 system/pdp1_am29xx/scripts/oracle_compare.py arith logic shift jumps skip index operate smoke demo
```

The oracle container is built from Ubuntu 24.04 with SIMH built at commit
`698dc8a1` (pinned in `spec/reference/simh_commit.txt`); PCRE is disabled
because only SIMH's SEND/EXPECT helpers use it.

## Panel and waveform

`run_panel.sh` serves the panel on port 8090. The panel drives the Verilator
model over stdin/stdout (`STATE`, `RUN`, `STEP`, `RESET`, `LOAD`, `KEY`, `TAPE`,
`WAVE`), displays the live registers, the console switches, the Type 30 points
and the typewriter stream, and captures 4,000 microcycles to
`work/waveform.fst` for the bundled Surfer viewer. The FST capture and the
`/waveform.fst` endpoint are exercised by the panel; the embedded Surfer view
is served from `/opt/surfer/webapp` like the other systems in this repository.
