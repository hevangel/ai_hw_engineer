# Independent oracle plan (issue #383)

Status: **first differential suite implemented and passing**. Thirteen directed
programs are executed on both the RTL and an independent emulator, and their
architectural state is compared; the comparison is what found two real
architectural defects in M5.

## Why an oracle is required

Every expectation in `tb/` and every reference expression in `formal/` is a
reading of the same manual (A22-6821-7) by the same author. Agreement between
them cannot detect a shared misreading — the failure mode recorded in
`failure_notes/README.md`. Issue #383 requires an external artifact produced
independently of this project.

## The artifact

| Field | Value |
|---|---|
| Project | `luiscunhacsc/s360-model30-v01` — IBM System/360 Model 30 instruction-level emulator in JavaScript, with a headless Node mode |
| URL | https://github.com/luiscunhacsc/s360-model30-v01 |
| Commit | `4c379fceda39250fad7385eac15630d99281debf` (2026-09-24) |
| File used | `src/core.js`, 42,903 bytes, SHA-256 `5034225ECB1378FE6FA990DEDA251619843E1E878E39AF127DC759EB2C903BDB` |
| Licence | **none stated** in the repository (no LICENSE file and no licence statement in the README). It is therefore treated as all rights reserved: used locally for verification only, never redistributed, never committed |
| Location | ignored `work/s360/oracle/s360-model30-v01-main/`, located through `ORACLE_ROOT` |

Other candidates considered: `rcornwell/S370` (Go, diagnostics pedigree, but
drifting to S/370), `rcornwell/microsim360` and `shirriff/ibm-system-360-50-simulator`
(both need recovered microcode images), `thejohnmathews/IBM-System-360-Simulator`
(partial coverage).

## What the suite does

`tools/oracle/run_diff.py` (host, needs python3 and node):

1. writes a program image for each case in `tools/oracle/cases.py` — words from
   address 0x000, program at 0x100, optional data/PSW words;
2. runs all cases on the RTL inside the project image
   (`tools/oracle/rtl_dump.py`, which builds `tb/tb_oracle.sv` once), because
   only the image has Verilator;
3. runs the same images on the emulator (`tools/oracle/js_run.js`), stepping by
   *retired instruction* (`cpu.instrCount`), not by `step()` calls;
4. compares PSW fields (IA, CC, ILC, program mask, system mask, P/W), all 16
   general registers, the program old PSW at 0x28/0x2C and words
   0x200-0x23F of storage.

Run it with:

```sh
python design/ibm_system360/tools/oracle/run_diff.py
```

The RTL image defaults to `ai-hw-engineer:latest`; override with
`--rtl-image`. `ORACLE_ROOT` points at the emulator checkout.

## Cases covered (13)

`LA`/`LR`, `AR` (CC 2), `SR` (CC 1), `LTR` (CC 0), `A` overflow (CC 3),
`CR` across the 32-bit boundary, `MVI`+`TM`, `TR` through a table, `MVN`,
`MR` across a register pair, `DR` quotient/remainder, `EX` with the R1 mask,
and `SLA`.

## Defects this found

1. **`DR`/`D` register placement.** The RTL put the quotient in the even
   register and the remainder in the odd one; A22-6821-7 p. 31 puts the
   **remainder in the even register and the quotient in the odd one**. Fixed in
   M5, with the testbench expectations corrected.
2. **`EX` mask source.** The RTL OR'ed its own instruction byte into the
   subject; p. 67 says bits 8-15 of the subject are OR'ed with bits 24-31 of
   the **register named by R1**, and R1 = 0 means no modification. Fixed in M5.

A third apparent divergence, the PSW ILC after an interruption, turned out to
be a harness accounting difference: the emulator performs the interruption
inside `step()` while the RTL retires only real instructions. Interruption
cases are therefore excluded from this suite until an event-aligned driver
exists (tracked as follow-up).

## Next steps

1. Add cases for every implemented operation (51 before M5, 54 after) and for
   pseudo-random operand/state combinations.
2. Compare interruption entry with an event-aligned driver (stop on old-PSW
   store instead of a retire count).
3. Use the emulator's DOS/360 support for the real-software regression #429
   once IPL and channels exist.
