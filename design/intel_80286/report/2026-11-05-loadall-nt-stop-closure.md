# 2026-11-05 - LOADALL, NT flag handling and development-stop closure

## Scope

This report covers work on PR #111, commits `365bc9e` to `49aea5b`.

## Changes

| Area | Change | Source |
|---|---|---|
| LOADALL (0F 05h) | Loads the 102-byte image at 000800h into every register, descriptor cache, GDTR and IDTR (`--loadall`) | Intel "Undocumented iAPX 286 Test Instruction" pp. 1-4; A35, A41 |
| JMP to an all-zero descriptor | Raised #GP(selector) instead of stopping the core | App. B B-54; found by k-induction |
| NT flag | POPF/IRET load NT; interrupt and trap gates clear it; task switches follow Table 8-2 (`--nt`, direct-TSS test) | App. B POPF/IRET, chapter 8 text, Table 8-2 |
| NT IRET with an invalid current TSS | #TS(back link) instead of a stop | App. B SWITCH_TASKS |
| Protected ENTER | #SS(0) when the allocated SP leaves the SS limit (`--enter-limit`) | App. B ENTER; A42 |
| Real-mode INSW/OUTSW at offset FFFFh | DI/SI and CX state taken from the physical captures | A36 |
| Physical replay | Every real-mode SingleStepTests file now replays: port I/O, ESC, WAIT and HLT added | Pinned revision `37c73ca` |

Post-mortem: [NT flag handling](../../../failure_notes/2026-11-04-intel80286-nt-flag-handling.md).

## Development stops

k-induction now proves these stops unreachable:
- segment-load completion (five sites);
- NT IRET reaching the ordinary far-return completion;
- the code-load request mismatch;
- the memory-check escalation.

REP before a non-string opcode no longer stops the core: the prefix is
ignored (assumption A43, 8086-compatible; App. B leaves it undefined).

Stops that remain:
- 0F 04h in real mode or at CPL 0. Intel's undocumented-opcode note says the
  286 "stops normal execution" and needs RESET, so the stop reflects that.
- the default state, which the state-bound invariant already excludes.

## Verification

All results are on RTL `bd74361` unless noted.

| Check | Result |
|---|---|
| Connected-core prove (k-induction) | PASS, 437 assertions |
| Connected-core BMC (depth 24) | PASS on `42e53c3`, `7e46383`, `ba2be56` and `bd74361` |
| Component formal (13 configurations: bmc, prove, cover) | PASS on `43bb26c`, before the ENTER change |
| `run_sim.sh` | 230 PASS |
| `run_hardware.sh` | PASS: 1,427,994 general records (every real-mode file, including port I/O, ESC, WAIT and HLT) plus the string, register and #GP sets |
| Vectors, native bus/core, mutation campaigns, IBM AT BIOS software, synthesis | PASS on `7e46383` |

## Open items

- Protected-mode CMPS, SCAS and OUTS limit faults keep the restartability-memo CX values. These differ by one from the real-mode captures.
- A connected-core cover run on `ba2be56` was started at the time of this report and takes a day or more.
