# Protected outer IRET fault priority — 2026-10-28

## Finding and change

Intel 210498-005 Table 7-4 orders the outer-return checks as current-stack
bounds, return-CS descriptor validation, outer-SS validation, then return-IP
limit. The first combined-fault case showed the RTL checking a null return CS
before it had validated the complete five-word current-stack frame. The next
case showed that checking the saved return IP during CS descriptor loading
raised #GP(0) before an invalid outer SS could raise #SS.

Protected outer IRET now validates the return-CS descriptor at offset zero,
after the complete source-frame preflight. This retains early #GP/#NP outcomes
for invalid CS descriptors while deferring only the saved-IP limit check.
After the outer SS passes validation, IRET raises restartable #GP(0) if the
saved IP exceeds the CS limit. It does not commit CS, SS, SP, IP or FLAGS on
that fault. Loading a valid CS descriptor may set its accessed bit before a
later SS or saved-IP fault; the regressions check this side effect.

## Source evidence

The Table 7-4 page was visually inspected in Chrome with `playwright-cli`.
The reference is Intel's
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
printed page 7-4, together with §9.4 for IRET's additional FLAGS word. The
inference that the five-word inter-level IRET frame uses the Table 7-4 full
span check follows from combining that table with §9.4. The captured page is
`work/iret_priority_20261028/source/intel-210498-005-table-7-4.png` (SHA-256
`6343e54926c18e7f5b029cc060a66c044a9ad06d78b331d69ab260a0df0e3455`).

## Regression coverage

`Vintel_80286 --protected-iret-faults` passes 36 executions across both READY
modes. The 12-execution priority matrix pairs:

- Invalid starting SP and a five-word frame crossing the current SS limit
  with null return CS; both raise #SS(0) first.
- Null and non-present return CS with null outer SS; #GP(0) and #NP(0048)
  precede outer-SS #SS.
- Null and non-present outer SS with an over-limit saved IP; both outer-SS
  #SS faults precede #GP(0), with #SS(0040) for the non-present descriptor.

The cases check exact event packets and restart frames, unchanged source
frames, source-frame and descriptor traffic, accessed-bit writes, handler
repair/retry and exact successor execution. The remaining focused scenarios
cover the valid outer return, inward IRET, CS descriptor recovery, five other
outer-SS fault forms, and current-stack bounds recovery.

## Verification

- Verilator 5.052 strict `-Wall` runner build passed. Build fingerprint:
  `3a293fe5700b7e5c8cbeae2dc285a6e175ed97eda728ea80b51f7ec95d20df07`.
- `Vintel_80286 --protected-iret-faults` passed; log SHA-256:
  `eb00293cbd95c1068ee100832fabbb88c91905c59e97e1d2473539893bde3738`.
- Full default `Vintel_80286` bootstrap passed with 71 PASS lines; log
  SHA-256: `7bc66b8cdf6623a0691e06bf52354aef1ca5bc47d8a0135164d5791531b0f9fd`.
- `scripts/preflight.py` passed; log SHA-256:
  `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa`.
- Yosys 0.69 `scripts/run_synth.sh` exited 0. All 12 targets produced JSON
  netlists and logs; every target log contains three `Found and reported 0
  problems` checks (36 total), with no `ERROR:` lines. The checksum file
  `work/iret_ss_ip_priority_20261028/synth/SHA256SUMS` has SHA-256
  `417c2a9e7c1b20968992b7ab74b8fa8ec1d87c507726be8d338e38e84885625e`.
- Current RTL SHA-256:
  `fc8576d5bc29eea755315abec7cf77603d309555e5e4cce1442a6dd37ba86fc7`.
- Bootstrap testbench SHA-256:
  `916c8d5c744be6e245f69c6033b716ca59f9848cafc684cbd32e9f3c56f4745d`.
- Runner manifest SHA-256:
  `f8c6e68a08a94a1b145c28f9568c21eb7ea62ba7df9b9940ebb11e59b78fafd1`.
- Runner binary SHA-256:
  `a01ae364db083b03398cb5c0efea2369c53cb389f5f1ee29cfe5d302958c34c7`.

The separate whole-core PDR remains active on an earlier RTL snapshot, so it
does not prove this change. Current-source connected-core proof, wider
protected exception/task-gate coverage, independent historical-software
evidence and full release acceptance remain open. Issue #80 remains Building
with Agent Codex, Path `ai_hw_engineer/design/intel_80286`, and its original
2026-10-23 Start date. The verified issue checkpoint is
[comment 6477632896](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6477632896).
