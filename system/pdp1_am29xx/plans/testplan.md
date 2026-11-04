# Test plan — PDP-1 Am29xx

## Levels

1. **Lint** — `scripts/run_lint.sh`: Verilator `--lint-only -Wall` over the
   system, the Am2901 pair and the Am2910. Waivers are local and explained:
   `UNOPTFLAT` (the Y→shift→D path is gated by the destination-code mux),
   `PINCONNECTEMPTY` (unused chip status pins), `UNUSEDPARAM` (the constants
   header is included per module).
2. **Instruction-level oracle** — every directed program runs on the RTL and on
   the SIMH PDP-1 simulator with the same memory image; the comparison covers
   PC, AC, IO and OV at each instruction start and stops at the first mismatch.
   This is the primary correctness gate.
3. **Directed programs** (`tests/`): `arith` (positive/negative zero, end-around
   carry, overflow, borrow), `logic`, `shift` (all twelve subcodes, single and
   multi-step), `jumps` (jmp/jsp/cal/jda/xct/indirect return), `skip` (every
   member plus the inverted form), `index` (idx/isp/sad/sas), `operate`
   (cla/cma/lat/cli/clf/stf), `smoke` (load/store/logic/shift) and `demo`
   (display + typewriter for the panel).
4. **Synthesis** — `scripts/run_synth.sh`: Yosys elaboration with a memory
   stub, `check` and cell/latch counts.
5. **Panel smoke** — load the demo, run to halt, verify display points and
   typewriter codes arrive, capture an FST.

## Excluded from the oracle diff

`mus` and `dis` (SIMH implements a later multiply/divide option for the same
opcodes; this machine follows the 1961 step definition) and every I/O device
(no external oracle for the device models). Both are recorded in the report
with the evidence that does exist: the handbook rule and the panel run.

## Regression command sequence

```sh
sh system/pdp1_am29xx/scripts/run_lint.sh
# RTL side
system/pdp1_am29xx/work/obj/Vpdp1_am29xx --batch --image work/arith.hex --trace work/arith.trace --max-micro 400
# Oracle side (pinned Ubuntu container)
bash system/pdp1_am29xx/scripts/oracle_simh.sh arith
python3 system/pdp1_am29xx/scripts/oracle_compare.py arith
sh system/pdp1_am29xx/scripts/run_synth.sh
```
