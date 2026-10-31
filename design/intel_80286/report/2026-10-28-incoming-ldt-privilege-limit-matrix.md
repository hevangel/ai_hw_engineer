# Incoming LDT privilege and limit matrix

**Date:** 2026-10-28  
**Scope:** Protected task entry through a non-null incoming LDT

## Architectural source

Intel's *80286 and 80287 Programmer's Reference Manual*, order 210498-005,
defines segment-load privilege checks in §7.4.1 and incoming-task validation
in §8.4, Table 8-1. The selector format identifies RPL as the requested
privilege level (Figure 7-7). During task entry, Table 8-1 requires valid,
readable DS/ES descriptors and DPL at least the task CPL for nonconforming
data. **Inference applied to the matrix:** combine the table's readability
check with selector RPL to test the effective boundary
`max(CPL,RPL) <= DPL`; unreadable DS/ES descriptors report `#GP`.
CS must match its selector RPL, SS DPL must match task CPL, and invalid CS/SS
selectors map to `#TS/#SS` respectively.

The relevant manual pages were visually checked in Chrome using
`playwright-cli`: Figure 7-7 and §7.4.1 (PDF pages 137–138), and Table 8-1
(printed page 8-6, PDF page 156). See [Figure 7-7 / §7.4.1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=138)
and [Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).

## Valid privilege coverage

The successful incoming-LDT matrix covers target CPL 0–2. CS and SS use
DPL=RPL=CPL. DS and ES independently cover each pair with DPL from CPL
through 3 and RPL from 0 through DPL. This exhausts the allowed
`max(CPL,RPL) <= DPL` combinations: 100 DS/ES pairings at CPL0, 81 at CPL1,
and 49 at CPL2, in both READY policies, for 460 executions total. RPL values
above DPL are excluded as unreadable; the existing incoming-segment fault
matrix separately checks DS/ES privilege denials.

All four descriptors reside in the incoming LDT, whose limit is exactly
`0x0027`; the ES descriptor ends at the final byte permitted by that limit.
Each case checks the exact task CS:IP successor, visible selectors, loaded
cache bases and validity, descriptor read order, all four accessed-bit writes,
task backlink and busy state, and instruction fetch order. The task reads
back DS/ES selectors but does not access the data segments, so this checks
task-entry acceptance without claiming subsequent memory access is allowed.

## LDT-limit fault coverage

Four incoming selectors use LDT selector `0x003c`, whose descriptor begins at
offset `0x0038`, beyond the LDT limit `0x0027`. Each case leaves earlier
segments valid and checks the Table 8-1 exception order:

- CS outside the LDT: `#TS(003C)`.
- SS outside the LDT: `#SS(003C)`.
- DS or ES outside the LDT: `#GP(003C)`.

In both READY policies, the tests verify the transferred task's exact saved
TSS context, backlink and busy state, handler error push, order and number of
prior descriptor reads, and that no descriptor read or accessed-bit write
targets the rejected entry. This is eight directed executions.

## Verification evidence

- `scripts/preflight.py` passed.
- Strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exited 0 with 173
  `PASS:` lines and no `FAIL:` or `ERROR:` lines. The retained log is
  `work/incoming_ldt_rpl_20261028_02/full_run.log` (SHA-256
  `d46fc73816b89ba72b67e7d7c8baf7ccf961aa3b6070d8aa748a38c12eb2266b`).
- The protected replay manifest passes 79 cases in both unstalled and READY
  stall modes. Its path is
  `work/incoming_ldt_rpl_20261028_02/protected_mode_sim_20261028T234024Z/build_manifest.json`
  (SHA-256
  `22eec44547181e1c8ae57cfc8fff244b05a82a555055e16e235bdb27e224710f`);
  the replay binary SHA-256 is
  `219f399b6f1688ad7552a97f640a9e9af203ab8ffe912a61eee6a683587806cc`.
- The full-run CPU binary SHA-256 is
  `6154c26dc7357ad77de5d8c839922fd0473c0250f4bed97bc8c207f8d4a57d5f`;
  its exact-source build manifest SHA-256 is
  `431d3aa1fccef54f1a1309d1228ca4d5902b2acf7eeefcd74577b5096bc31784`.
  The runner fingerprint is
  `4a43568ff25062fdb8f911ac3cdd0b3d1ae66d43a63d79a0ac275fb4a1396de2`.
- `tb/bootstrap.cpp` SHA-256 is
  `74621cc2c39ff02a470b4d6209da730b53287fc56fbd7829450e028ca19bc00e`;
  `src/intel_80286.sv` remains
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.

## Limits and next work

This is directed simulation evidence for incoming LDT privilege boundaries
and segment-selector limit faults. It does not prove every LDT descriptor
type, all task-switch fault phases, or the whole CPU. No RTL behavior changed,
so the previous 13-target Yosys 0.69 synthesis remains applicable. The
preserved whole-core PDR is still active on a different 21-file source
snapshot and cannot prove these current test changes. Current-source
connected-core formal, broader task-switch coverage, authentic historical
software, native timing qualification and the full release gate remain open.

Issue #80 checkpoint:
[comment 6483636717](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483636717).
