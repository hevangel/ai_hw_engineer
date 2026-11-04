# 2026-11-04 - Full physical-capture replay and the fixes it forced

## Scope

The physical Harris-286 replay now covers every real-mode file in the
pinned SingleStepTests/80286 revision `37c73ca`, except port I/O
(E4-E7, EC-EF, 6C-6F), ESC (D8), HLT (F4) and WAIT (9B). Before this change
it covered 28 opcode files (68,510 register-only records).

| Importer | Files | Records replayed | Records excluded |
|---|---|---|---|
| `prepare_hardware_tests.py` (existing) | 28 | 68,510 | 7,490 outside the register adapter |
| `prepare_protection_hardware.py` (existing) | 1 | 52 | - |
| `prepare_string_hardware.py` (new) | 10 | 50,000 (1,865 #13) | none |
| `prepare_general_hardware.py` (new) | 301 | 1,368,994 | IF/TF/IOPL setup, prefetch queue, final TF, revoked |

Each record replays in both READY modes and checks:
- the exact general registers, segment registers and IP;
- the FLAGS bits the capture metadata marks defined;
- every captured RAM byte;
- the fetch addresses;
- for faults, the IVT reads and the three-word frame;
- the HLT successor.

`run_hardware.sh` runs all four files. Set `INTEL_80286_GENERAL_PER_FILE` to
sample a quick loop; omit it for sign-off.

## Defects found and fixed

| Area | Old behavior | Physical behavior | Assumption |
|---|---|---|---|
| REP LODS, REPNE MOVS/STOS/LODS | development stop | execute; F2 acts as REP | A36 |
| String word at FFFFh, #13 | SI/DI/CX unchanged | advanced per the failure-note table | A36 |
| ENTER push wrap, odd SP | shutdown | #13, SP unchanged | A29 |
| POP m to word at FFFFh | #13 before the pop, SP unchanged | pop, keep SP+2, then #13 | A37 |
| AAM 0 | FLAGS unchanged | OF/SF/AF/CF clear, ZF/PF from AL>>1 | A38 |
| IDIV overflow | exact range check | 286 division model (four records return 80h) | A39 |
| 4-byte operand at FFFEh | #13 | second word wraps to offset 0000 | A40 |

Also added from Intel's undocumented-opcode note (A35):
- F1h is a no-function prefix.
- 65h-67h and 0F 07h-FFh raise #UD.
- 0F 04h/05h raise #GP(0) at protected CPL>0.

Post-mortems:
- [string fault state and REP forms](../../../failure_notes/2026-11-04-intel80286-string-fault-state-and-rep-forms.md)
- [general replay defects](../../../failure_notes/2026-11-04-intel80286-general-capture-replay-defects.md)

## Verification

See the PR #111 comment for the final run list and results:
- connected-core prove, BMC
- `run_sim.sh`
- full `run_hardware.sh`
- the muldiv unit formal tasks

## Limits

- The captures are real mode only. Protected-mode behavior for the same
  operations still follows Intel's documents and the restartability memo.
  The memo's CMPS/SCAS CX values disagree with the real-mode captures.
- No capture covers a repeat prefix before a non-string opcode. That
  combination is still a development stop.
- 0F 04h/05h at real mode or CPL 0 stop the core. LOADALL is not
  implemented.
- I/O, ESC, WAIT and HLT files are not replayed. IN returns FFh in the
  captures, and the bench port model differs.
