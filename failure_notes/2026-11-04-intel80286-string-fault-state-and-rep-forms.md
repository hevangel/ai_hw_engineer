# 2026-11-04 - 80286 string #13 register state and REP forms disagreed with a physical 286

## What broke

Two defects in the string instructions, both found by replaying physical
Harris-286 captures (SingleStepTests/80286 revision `37c73ca`, files A4-A7 and
AA-AF). The design's own suite did not find them.

1. **Stopped REP forms.** The core stopped (`fault_code_o=1`) on REP LODS and
   on REPNE (F2h) before MOVS, STOS or LODS. The captures execute all of
   them: F2h acts as REP for a non-compare string, and REP LODS runs until
   CX=0. Over a thousand records per file use these prefixes.
2. **Register state at a word-FFFFh #13.** When a word string operand sits at
   offset FFFFh in real mode, the core raised #13 with SI, DI and CX
   unchanged. The physical chip leaves the pointers and CX advanced for the
   accesses it reached. The first mismatch was MOVSW with SI=DI=FFFFh: the
   capture has SI=0001h and DI unchanged. The 1,865 fault records give these
   rules (e is the element step; R means a REP prefix is present):

   | Instruction | Faulting access | SI | DI | CX if R |
   |---|---|---|---|---|
   | MOVS | source | +e | 0 | -1 |
   | MOVS | destination | +e | +e | -2 |
   | CMPS | ES:DI (read first) | 0 | +e | 0 |
   | CMPS | DS:SI | +e | +e | -1 |
   | STOS | destination | 0 | +e | -2 |
   | LODS | source | +e | 0 | -1 |
   | SCAS | ES:DI | 0 | +e | -1 |

   Elements completed before the fault keep their normal effects.

## Why verification missed it

- The physical replay importer accepted only ADD/ADC/SBB/SUB/CMP immediates,
  INC/DEC and TEST /1, and it rejected F0/F2/F3 prefixes. No string file was
  replayed.
- Directed tests derived the real-mode FFFFh fault state by reasoning from
  "no retirement" rather than from an external artifact. That is the shared
  misreading the escaped-defect rules warn about.
- The REP restrictions were treated as invalid encodings. No evidence was
  consulted before stopping on them.

## Fix

- `opcode_valid` rejects a repeat prefix only before a non-string opcode
  (assumption A36). The string engine already ignores ZF for non-compare
  strings.
- The `STRING_START` word-FFFFh path applies the table above before entering
  #13 (assumption A36).
- `scripts/prepare_string_hardware.py` imports 50,000 records, 48,135
  completions and 1,865 #13 faults. `hardware_replay.h` replays them as
  `HWSTRING`/`HWSTRFAULT` with exact registers, flags, RAM, fetch addresses,
  IVT/frame traffic and HLT successor in both READY modes. `run_hardware.sh`
  runs the new vector file.

## Open points

- Intel's restartability memo asks the handler to add one more to CX for
  CMPS and SCAS than these captures show. Protected-mode CMPS keeps the memo
  values. A protected-mode capture is needed to decide which is right.
- A repeat prefix before a non-string opcode has no capture and still stops.
- Protected-mode LODS and SCAS limit faults now use the same captured values,
  on the argument that real-mode overrun uses the same limit microcode.

## Prevention

- Before declaring an encoding invalid or a fault state final, check whether
  the pinned capture set has a file for that opcode, and replay it.
- Widen the physical importer opcode by opcode, and keep prefixed records
  instead of rejecting them.
