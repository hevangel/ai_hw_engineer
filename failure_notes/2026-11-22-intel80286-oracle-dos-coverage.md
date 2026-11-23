# 2026-11-22 — 80286 Unicorn replay: PC DOS code outside its coverage

## What broke

The Unicorn replay of the IBM PC AT runs (`design/intel_80286/scripts/bios_replay.py`
through `system/ibm_pc_at_5170/scripts/check_post_trace.py`) was extended
from BIOS POST and a script-built boot program to whole PC DOS 1.00 and 2.00
sessions (`system/ibm_pc_at_5170/scripts/run_dos_8086.sh`). Real software
stopped it three times. None of the stops was a CPU disagreement; all three
were defects or gaps in the oracle:

1. **Decoder whitelist.** At physical 7C8Bh, the DOS 1.00 boot sector's
   `JMP FAR CS:[mem]` (FF /5): `generate_firmware_trace.decode()` accepts
   only the forms the BIOS uses and returned no decode. A scan of both
   traces found DAA, the 82h immediate group, CALL FAR direct (9Ah), JMP FAR
   indirect, XLAT and instruction fetches at 1000C0h (DOS 1.00's CALL 5
   entry, wrapped by the A20 gate) outside the oracle as well.
2. **LAHF compared undefined flags.** At F600:26DC (ROM BASIC) the CPU's
   AH after `OR` then `LAHF` was 12h, Unicorn's 02h. OR leaves AF undefined
   (210498-005 Appendix B); the replay already excluded AF from the flags
   comparison after OR, but compared LAHF's AH with a fixed mask (D5FFh)
   that included AF.
3. **Self-modifying code.** At 0070:0A1D (PC DOS 2.00 IBMBIO, `MOV CS:[0A2E],DL`
   into the code a few bytes ahead) Unicorn 2.1.4 run with `count=1`
   abandons the instruction to retranslate the page and returns with IP
   unchanged, every time it is retried (reproduced in a ten-line Unicorn
   script). The replay reported a next-CS:IP mismatch.

## Why verification did not catch it

The oracle was only ever run on the BIOS's own code and on a boot program
written for the test, which together use none of these forms, flag
sequences or self-modifying stores. The whitelist was sized to what had
been run, so its gaps were invisible until other software ran. The LAHF
mask was written when every flag LAHF copies was defined at the BIOS's
LAHF sites.

## Fix

- `generate_firmware_trace.decode(extended=True)` accepts DAA/DAS/AAA/AAS,
  9Ah, FF /5 with a memory operand (the register form stays undefined), XLAT
  and 82h as 80h (assumption A34 of `design/intel_80286/spec/spec.md`).
- `bios_replay.py`: DAA/DAS leave OF, AAA/AAS leave OF/SF/ZF/PF out of the
  comparison (undefined in 210498-005 Appendix B); LAHF's AH is compared
  only in the flags still defined and the CPU's AH is then adopted
  (`lahf_undefined_adopted`); a sequential instruction that Unicorn leaves
  at the same IP is run again up to its next address (`emu_start` with an
  end address, which completes the store; `self_modifying_restarts`), and
  its transfers are then compared as usual, so a store that is not
  idempotent would still fail; an instruction fetch at or above 1 MB while
  the A20 gate is low is folded to the low address
  (`a20_folded_fetches`), as data transfers already were.
- No RTL change: the CPU's results at all three points are the defined
  results (or, for AF after OR, an undefined one Unicorn cannot judge).

Re-verification: the full replays of both DOS runs (see
`system/ibm_pc_at_5170/report/2026-11-22-8086-compatibility.md`) and
`design/intel_80286/scripts/run_software.sh` (BIOS firmware trace, timer,
DMA and native-bus BIOS replays).

## Prevention

- An oracle stop is classified before anything else is changed: CPU
  disagreement, oracle coverage gap, or oracle defect. Only the first leads
  to an RTL change, and only with an external source for the expected
  behaviour.
- Before extending the replay to new software, scan its trace for forms the
  decoder rejects (decode every retired instruction against a memory image
  rebuilt from the trace's own writes and DMA records) instead of finding
  them one replay at a time.
- Any comparison of a value derived from the flags (LAHF, PUSHF, the flags
  image of an interrupt frame) uses the running defined-flags mask, never
  a fixed one.
