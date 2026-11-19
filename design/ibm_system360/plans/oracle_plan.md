# Independent oracle plan (issue #383)

Status: **candidate selected; not integrated**. Nothing in this repository is
yet validated against an independent implementation, and no compatibility claim
is made.

## Why an oracle is required

Every expectation in `tb/` and every reference expression in `formal/` is a
reading of the same manual (A22-6821-7) by the same author. Agreement between
them cannot detect a shared misreading — the failure mode recorded in
`failure_notes/README.md`. Issue #383 requires an external artifact that was
produced independently of this project.

## Requirements

1. Executes S/360 machine code instruction by instruction, not only whole
   operating-system jobs.
2. Exposes architectural state (general registers, PSW, storage) after an
   instruction, so traces can be compared.
3. Runs headless on Linux without proprietary media.
4. Has a usable licence for local differential testing (redistribution is not
   required; the artifact stays in the ignored `work/` tree).
5. Can be pinned to an exact commit and hashed.

## Candidates surveyed (2026-11-18)

| Candidate | What it is | Assessment |
|---|---|---|
| `luiscunhacsc/s360-model30-v01` (https://github.com/luiscunhacsc/s360-model30-v01) | JavaScript S/360 Model 30 instruction-level emulator (`src/core.js`: CPU, interruptions, channel programs, storage keys, interval timer) with a headless Node mode (`test/dos4.js`) and unit tests; runs genuine DOS/360 26.2 on embedded 2311 packs | **Primary candidate.** Instruction level, no build tool, Node-runnable, and the DOS images give a path to a real-software regression later. Licence not yet recorded; the per-commit hash and an instruction-level API still need to be established. |
| `rcornwell/S370` (https://github.com/rcornwell/S370) | Go emulator derived from a SimH-based 360/370 emulator; reportedly passes CPU diagnostics | **Secondary.** Strong diagnostics pedigree, but it is drifting toward S/370-only and needs a Go toolchain. Useful for S/370-era cross-checks, not for S/360-specific behaviour. |
| `rcornwell/microsim360` | Microcode-level Model 30/50/65 simulator | Needs recovered microcode ROMs plus SDL; valuable for the microarchitecture milestone (#388), not usable as an ISA oracle today. |
| `shirriff/ibm-system-360-50-simulator` | Model 50 microcode simulator | Same limitation: requires the microcode image. |
| `thejohnmathews/IBM-System-360-Simulator` | Student C simulator with a cache model | Partial instruction coverage; not usable as an oracle on its own. |

## Chosen approach

1. Pin `luiscunhacsc/s360-model30-v01` at a recorded commit, download it into
   the ignored `work/` tree, and record URL, commit, file hashes and licence in
   `spec/sources.md`.
2. Build a small driver in `design/ibm_system360/tools/oracle/` that:
   loads a program image into both engines, steps **one instruction at a time**,
   and compares general registers, the PSW fields the core implements
   (instruction address, condition code, ILC) and the storage bytes a test
   declares.
3. Start with the 51 implemented operations, one directed case each, then add
   pseudo-random operand/state generation.
4. Feed divergences back as failures against the RTL (with the manual page as
   the arbiter) and record the outcome in the report.

Until step 2 exists and passes, the "no independent oracle" limitation stands in
every report, and no wording stronger than "implements what this project read in
the manual" may be used.
