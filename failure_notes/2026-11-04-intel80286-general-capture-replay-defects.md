# 2026-11-04 - 80286 defects found by replaying the full physical capture set

## What broke

Replaying the pinned physical Harris-286 captures (SingleStepTests/80286
revision `37c73ca`, 301 real-mode opcode files, about 1.37 million records)
found four defects. The design's own suite missed all of them. Each fix
follows the captures, because Intel's documents either say nothing or call
the result undefined.

1. **ENTER stack wrap (A29).** With odd SP=000Fh, a push that wraps raised
   real-mode shutdown. The captures raise exception 13 with SP unchanged and
   the frame at the original SP. Intel lists no real-mode ENTER exception.
2. **POP r/m destination fault (A37).** A POP to a word at offset FFFFh
   faulted before the stack read and left SP unchanged. The physical chip
   reads the stack first, keeps SP+2, then raises 13 with the frame below the
   new SP. The saved IP still names the POP.
3. **AAM 0 flags (A38).** Exception 0 left FLAGS unchanged. The captures
   clear OF, SF, AF and CF and set ZF and PF from AL>>1 before the fault, and
   the pushed FLAGS word carries those values.
4. **IDIV overflow detection (A39).** The core computed the exact quotient and
   faulted whenever it was out of range. Four byte records return quotient 80h
   with no fault although the true quotient is below -128. One division
   model reproduces all 9,967 IDIV records: magnitudes, an operand-width
   partial remainder that drops the shifted-out bit, no high-half pre-check,
   and a final signed range check.

The capture metadata also lists no undefined flags for C0 /n. C1 /n and
D2 /n mark OF undefined. The importer uses the C1 /n mask for C0 when the
count is not 1. This is a comparison gap in the metadata, not an RTL defect.

## Why verification missed it

- Before this change, the physical replay covered only 68,510 records from
  28 opcode files and rejected memory operands, prefixes, faults and control
  transfers.
- A29 was recorded as an assumption that needed independent validation, but
  nothing checked it.
- Directed tests derived divide and fault state from Intel's prose and from
  the RTL's own reading. That is the shared-misreading pattern.

## Fix

- `scripts/prepare_general_hardware.py` imports every real-mode file except
  port I/O, ESC, HLT, WAIT and the string files (which have their own
  importer). It checks each file against the pinned Git blob list in
  `scripts/hardware_tree_v1_real_mode.json`. The FLAGS comparison is narrowed
  only to the bits the metadata marks defined.
- `hardware_replay.h` replays these records as `HWGEN`/`HWGENFAULT`: exact
  registers, defined FLAGS, RAM, fetch addresses, IVT/frame traffic and the
  HLT successor, in both READY modes. With `I286_HW_SURVEY` set, it reports
  every failing file instead of stopping at the first failure.
- RTL fixes: `I286_ENTER_WRAP`, the real-mode POP m path, `aam_zero_flags`
  and the IDIV iteration in `intel_80286_muldiv.sv`.

## Prevention

- Run `run_hardware.sh` (full corpus) before every 80286 sign-off. Use
  `INTEL_80286_GENERAL_PER_FILE` only for quick local loops.
- Each new `ASSUMPTION` needs a capture query, or an explicit note that the
  pinned captures do not cover it.
