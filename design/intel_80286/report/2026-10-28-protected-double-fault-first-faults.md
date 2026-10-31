# Protected double-fault first-fault coverage — 2026-10-28

## Source and scope

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines the 286 double-fault rule: a second fault during one instruction
selects vector 8 when the first fault is vector 0, 10, 11, 12 or 13. The
double-fault error code is null and the saved context identifies the original
instruction. This checkpoint extends the source-backed tests for first faults
`#NP` (vector 11), `#SS` (vector 12), and `#TS` (vector 10), complementing
existing `#DE` and `#GP` cases.

## Cases and observations

The protected `--iopl-controls` regression adds eight executions across both
READY policies. The `#NP` and `#SS` cases make the IDT limit exclude their
handler gates while admitting vector 8; an invalid vector-8 gate makes the
escalated packet observable.

- **`#NP`:** a far jump reloads a non-present current-level code descriptor.
  The regression checks the eight GDT descriptor reads, no accessed-bit write,
  then exactly the eight vector-8 IDT reads. The packet is restartable vector 8
  with error code zero, the original `CS:IP=003B:0400`, FLAGS and SP, and no
  instruction retirement or event-frame writes.
- **`#SS`:** a user stack descriptor is reloaded with limit `00FEh`, SP is set
  to `0100h`, and `PUSH AX` faults because its two-byte write crosses the limit.
  The regression checks saved `CS:IP=003B:0408`, the original SP, no retirement
  or frame writes, and only the eight vector-8 IDT reads before sticky shutdown.
- **`#TS`:** a software task-gate transfer loads an incoming task whose LDTR
  selector names a non-LDT descriptor. Its #TS handler gate is malformed, so
  gate validation raises the second protection fault and selects null-error
  vector 8. One case makes the #DF gate invalid and checks sticky shutdown with
  incoming `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, and the exact #TS/#DF
  gate reads. The companion case uses a valid #DF task gate, checks the
  faulting TSS image plus backlink/busy updates, and executes the handler's
  HLT at the exact successor.

The focused build uses Verilator 5.052 `-Wall`; `--iopl-controls` passes all
480 privilege scenarios, existing #DF/task-gate coverage, and all eight new
`#NP/#SS/#TS` executions. The full `scripts/run_sim.sh` exits 0 with 165
`PASS:` lines and no `FAIL:` or `ERROR:` markers. The exact-source protected
replay manifest reports PASS for 79 cases in both unstalled and READY-stalled
modes. The 13-target Yosys 0.69 matrix for the same RTL snapshot passes; all
target logs have zero-problem `check -assert` results. The full reset and
synthesis evidence is summarized in the
[reset source audit](2026-10-28-reset-source-audit.md).

## Exact-source evidence

The focused CPU runner build uses Verilator 5.052 `-Wall`; its fingerprint and
source records are in the build manifest. The protected replay manifest binds
the 79-case, two-mode result to the current RTL. The SHA-256 list for the
current source, focused run and full run is
`work/df_np_ss_ts_task_full_20261028/SHA256SUMS` (SHA-256
`be44eec8ee7c3403ce76a6b53c77a8f6d8f759463b9757959d8162763014cd37`).
The GitHub checkpoint was posted and read back at
[comment 6479402130](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6479402130).

| Artifact | SHA-256 |
|---|---|
| `src/intel_80286.sv` | `fc8576d5bc29eea755315abec7cf77603d309555e5e4cce1442a6dd37ba86fc7` |
| `tb/bootstrap.cpp` | `20478bad1cb47039d2500221a47f798226ff36d3c153b6194e0c3f8f6026176d` |
| Focused `--iopl-controls` log | `02f260f67626f6b1149e157b2c4114a5f33db441a99bfc8ba9f4e72360f55cb0` |
| Focused build manifest | `5d4868cf3211feb7c7fd3beadbe39890e3cffeb49ade50060de629b0ebb27be0` |
| Full `run_sim.sh` log | `d086d280b7a208bc8ffadd4111b41d91c037855c6095a67e6722a0160c6797f2` |
| Full simulation build manifest | `f6da1b0915e7afcab47090005a031b6ab49e55aae98d5ebe2c864c1d3dbb7ad2` |
| Protected replay manifest | `14412ecf4473380baf74c66a056eceefebc362915f65b806863ee42f7f030163` |

## Remaining limits

The new #TS coverage uses an invalid incoming LDTR during a task-gate switch,
then a malformed #TS handler gate. It does not cover every #TS source, every
second-fault class, or faults in all later event/task-entry phases. Full #DF
classification/delivery, current-source connected-core formal proof,
independent historical-software execution and the release gate remain open.
