# Protected IOPL controls — 2026-10-27

## Result

Implemented protected-mode I/O privilege enforcement and the related IF/IOPL
flag restoration rules. The architectural source is Intel's
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
especially §§3.11.1, 3.11.3, 4.1 and 10.1. The contract is recorded in
[`spec/iopl_control.md`](../spec/iopl_control.md).

In protected mode, direct and string `IN`/`OUT`, plus `CLI`/`STI`, now raise
restartable `#GP(0)` when `CPL > IOPL`, before port or string-operand traffic.
Protected `POPF` and `IRET` load IOPL only at CPL 0. They load IF only in real
mode or when `CPL <= IOPL`. The prior real-mode flag behavior is retained.

## Verification evidence

The focused `--iopl-controls` regression passes 288 scenarios across both
READY modes:

- 256 direct I/O scenarios: eight opcode forms × four CPLs × four IOPL values
  × two READY policies. Allowed cases check port, direction, byte/word width,
  data, register result and exact successor. Denied cases check the restartable
  `#GP(0)` packet at the instruction start, unchanged AX and ports, no I/O
  request and no retirement.
- 16 REP string scenarios: byte/word INS/OUTS at allowed CPL 0 and denied
  CPL 3. They check one exact element or a pre-element fault at the REP prefix,
  including CX/SI/DI and memory/port effects.
- Eight CLI/STI scenarios cover allowed and denied forms, checking IF and the
  fault packet.
- Eight POPF/IRET scenarios check CPL-0 IOPL/IF updates and CPL-3 ignored
  IOPL/IF updates.

The full default Verilator bootstrap also passes, including all earlier
bootstrap cases. Its log is
[`work/iopl_controls_20261027/full_bootstrap.log`](../work/iopl_controls_20261027/full_bootstrap.log).
Release preflight passes. The runner used Verilator 5.052 and g++ 15.2.0;
build fingerprint: `9d222bd231cfc141d8b4b6719e80191c3938db4d524be3fc2fb004b3251b29d3`.

## Source identity and limits

- RTL SHA-256: `77e82f15c62f8abc8913fdf7ce884ab06dc15282c0036debc14a43f3ad61cabe`
- Testbench SHA-256: `b38cc1821844fc210226929b074735a4f3a3a86245e1839e58f72152f0458d44`
- Contract SHA-256: `70b127d90fc503a53a2910c343c8ffd1902d53d0096dd37cf0317397996068a4`
- Formal property SHA-256: `85b8d6f497c927d084f21da29b10fa0be1ea8438242e2de735ee655e20056f53`

No connected-core formal run has evaluated this RTL/property pair. The active
`_21` cover and PDR solvers use earlier sources. This slice does not implement
task switching, task-gate I/O behavior, an 80386 I/O permission bitmap, native
port timing, all FLAGS/NT semantics, or full-chip acceptance. Current-source
formal work, the aggregate audit, independent historical software and the
full release gate remain open.

Issue #80 checkpoint: [IOPL implementation update](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439046933).
