# Protected HLT privilege — 2026-10-27

## Result

Implemented the protected-mode HLT privilege rule from Intel's
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
§3.11 and the HLT instruction entry. HLT executes only at CPL 0 in protected
mode. At CPL 1, 2 or 3 it raises restartable `#GP(0)` before halting or
retiring, independent of IOPL. Real-mode HLT behavior is unchanged. The
[HLT privilege contract](../spec/hlt_privilege.md) records the scoped rule.

## Verification evidence

The focused `--iopl-controls` regression passes 320 scenarios across both
READY policies. The 288 IOPL/FLAGS scenarios cover direct byte/word immediate
and DX `IN`/`OUT`, REP INS/OUTS, CLI/STI, and POPF/IRET IOPL/IF handling. The
additional 32 HLT scenarios cover every CPL/IOPL pair in both READY modes:
CPL 0 halts at every IOPL, while CPL 1–3 receive `#GP(0)` at every IOPL. The
full default Verilator bootstrap passes, including ring-3 tests updated to
stop at NOP successors instead of issuing now-privileged HLT. Release
preflight passes.

The runner uses Verilator 5.052 with `-Wall` and g++ 15.2.0. Its build
fingerprint is
`b70b79df2eac78d675627c4e47bd6f354d9efdd8f862b853249cfdd75c63c991`, and its
binary SHA-256 is
`2efd2a7df1d7723d87cd8e923167b0910f713f4a29c15f79a6f92b3ba449c325`. The
full bootstrap log is
[`work/iopl_controls_20261027/full_bootstrap.log`](../work/iopl_controls_20261027/full_bootstrap.log).

## Source identity and limits

- RTL SHA-256: `2ca0d9a8f46e9b3774505593c0dcebb0a70ec6530e848c3fb0d39eccba55fec1`
- Testbench SHA-256: `a5950b687d035d4dad76ba2a5dae07d6d9c39c7ed9af0273700020eed3ce9fc9`
- HLT contract SHA-256: `a428fe243fca8e87f41d71e11e6bced6d56b28d3aa4cd4f550588e1b2be8d95f`
- IOPL contract SHA-256: `70b127d90fc503a53a2910c343c8ffd1902d53d0096dd37cf0317397996068a4`
- Formal property SHA-256: `85b8d6f497c927d084f21da29b10fa0be1ea8438242e2de735ee655e20056f53`
  (298 assertions, one assumption and 49 covers)

No connected-core formal run has evaluated this RTL/property snapshot. The
older `_21` cover and PDR jobs still use earlier source; their progress is
not evidence for this change. Current-source connected-core formal work,
task switching, broader privilege/fault combinations, independent historical
software and full-chip acceptance remain open. See the
[continuation status](../../../plans/286/STATUS.md) for the active work queue
and formal-job state. The combined IOPL and HLT checkpoint is recorded in
[issue #80](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439265529).
