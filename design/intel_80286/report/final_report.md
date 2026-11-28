# Intel 80286 verification report

Current state of `design/intel_80286` on branch
`design/intel-80286-release-gate`, combining the issue #284 fixes with the
2026-11-24 single-pass release-gate closure (`ai-hw-engineer:latest`: Verilator
5.052, Yosys 0.69, SymbiYosys, Yices 2.7.0, ABC). See the
[release-gate closure report](2026-11-24-release-gate-closure.md) for exact
formal witness architecture details and digests. History before issue #284 is
in the [archived README status log](2026-11-22-readme-status-log.md) and the
dated reports in this folder.

## Issue #284 review findings

The review (issue #284, revised 2026-11-20) compared protected-mode control
transfers, task switching and event handling with Intel 210498-005. Each
finding is one commit, except 15 and 17, which change the same lines and
share one. Findings 1-9 were started by the issue's previous owner and
re-verified here.

| # | Finding | Fix | Regression evidence |
|---|---|---|---|
| 1 | #DF through an interrupt or trap gate shut down | Vector 8 accepts interrupt, trap and task gates (App. B INT, p. B-49) | Bootstrap #DF gate matrix; PCE `review284` scenarios |
| 2 | Outgoing TSS needed limit 43; LDT word overwritten | Save words 0-13; current TSS limit >= 41 (p. B-12) | Outgoing-TSS limit/save cases |
| 3 | CALL/JMP task gate with a bad TSS selector raised #TS | #GP(TSS selector) (pp. B-25, B-57) | Direct task-fault matrix; PCE waiver (PCE-286 uses #TS) |
| 4 | IRET to an available back-link TSS raised #GP | #TS(new TSS), busy before present (p. B-51) | Back-link fault cases |
| 5 | Call-gate stack switch rejected expand-down stacks | Expand-up and expand-down room tests | Expand-down call-gate matrix |
| 6 | Outer IRET and RETF disagreed on a bad return SS | Appendix B for both (assumption A31 rewritten) | Outer IRET SS fault matrix; the A31 oracle waivers removed |
| 7 | Target IP limit tested before stack checks | Stack checks first, then the IP limit | Stack-before-IP cases (CALL, gate, INT) |
| 8 | Present tested before type on TSS targets | Type (#GP/#TS) before present (#NP) | Type-before-present cases |
| 9 | Direct task switch re-checked the current TSS descriptor | Mark new TSS busy first; test only the cached TR | Current-TR cases |
| 10 | Near transfer beyond the CS limit saved the target IP | #GP(0) at the transfer instruction (assumption A47) | New PCE `near_limit` family, 23 scenarios |
| 11 | Block-level combinational loop (newer Verilator) | `wide`/`destination` decode in its own block | Pinned-Verilator lint clean (the newer build was not run) |
| 12 | Unused PEDC module and dead CS-checker inputs | Removed, with their tests and formal task | Code-check/load tests, formal and mutations |
| 13 | Documentation and release-gate drift | See below | This report |
| 14 | CPL read from the CS selector | CPL register (assumption A41 revised) | New `--pe-entry` test |
| 15 | STI/MOV SS shadows did not hold a WAIT | Shadows cover a polling WAIT (assumption A48) | New STI;WAIT and MOV SS;WAIT cases |
| 16 | NMI edge lost while a pending NMI was selected | Edge stays pending | New event-controller case |
| 17 | Outer IRET opened an interrupt shadow | No shadow | New `--outer-iret-shadow` test |

The new directed tests for findings 10 and 14-17 were run against the
previous source (`main`, `cad8b27`) and fail there. For findings 1-9 the
regressions are the previous owner's extensions of the existing fault
matrices; they were not run one by one against `main`, but the review's own
harness shows `main` reproduces each of those defects. The review's harness,
`tb/review_284_repro.cpp`, gives on `main` and on this branch:

| Case | Intel 210498-005 | `main` | This branch |
|---|---|---|---|
| T1 | #DF handler entered | #DF, then shutdown | #DF handler entered |
| T2a | Switch completes with current TSS limit 41 | #TS(0028) | Switch completes |
| T2b | TSS+42 untouched | Overwritten with 0000 | BEEF kept |
| T3, T3b | #GP(0FF8), #GP(0034) | #TS | #GP |
| T4 | #TS(0030) | #GP | #TS |
| T5, T9 | Expand-down stacks accepted | #SS(0) | Enter at the expected SS:SP |
| T6 | #SS(0) before the IP limit | #GP(0) | #SS(0) |
| T7a, T7b | #GP(0058) for both | #SS for IRET, #GP for RETF | #GP for both |
| T8 | #TS(0) before the IP limit | #GP(0) | #TS(0) |
| T10 | Open question | Saved IP 0180 (the target) | Saved IP 0100 (the JMP), assumption A47 |

### Finding 13

- `scripts/run_all.sh` now runs the PCE-286 oracle (`run_pce_oracle.sh`).
- `design/README.md` has one 80286 row.
- The README's append-only status log moved to
  [2026-11-22-readme-status-log.md](2026-11-22-readme-status-log.md); the
  README now has one current status.
- This report is the design's `final_report.md`.
- Assumptions A45 and A46 cite the manual (pages B-60, 11-3, 10-5, B-31),
  re-read from the local 210498-005 text layer.
- Two mutations in the release gate no longer matched the source and stopped
  the gate before it tested anything; both are fixed (see Known issues for
  the suites outside the gate).

## Release gate

Commands, from the repository root in the tool container:

```sh
sh design/intel_80286/scripts/run_all.sh --work-dir <empty dir>
```

The full release gate ran end-to-end in a single uninterrupted pass
(`work/release_20261124`, formal epoch `release.ClGBL2`, `12,907 s` wall time,
exit `0`), with every artifact bound to `src/intel_80286.sv` SHA-256
`5dc923fc3573b17c04e65e4e5072745d79631c89cbbe440400dec41b2eda6c81` and
`formal/intel_80286_props.sv` SHA-256
`b02d3d3f2c5c92d0bf1a985709a0886674f1b774ba9cc0270deb6e0e607f6b5f`.
See [2026-11-24-release-gate-closure.md](2026-11-24-release-gate-closure.md).

| Gate | Result |
|---|---|
| Preflight and unit tests | Pass (`preflight.py`: `442`/`1`/`52`; `check_mutation_patterns.py`: `119` patterns across all `16` suites; `test_preflight`, `test_audit_formal`, `test_build_runner`, `test_work_paths` pass) |
| Lint, `verilator --lint-only -Wall` | Clean (`0` warnings) |
| Component formal (12 suites: access, bus owner, cached reference, code check, code load, datapath, decimal, EA, event control, mul/div, segment check, segment load) | `36/36` tasks (`bmc`, `prove`, `cover`) pass |
| Connected-core formal (`intel_80286.sby` + witnesses) | `bmc` PASS (`5,989 s`); `prove` k-induction depth 12 PASS (`1,014 s`); `cover` depth 15 PASS (`1,100 s`, `14/14` shallow blind covers); `intel_80286_cover_witnesses` PASS (`81 s`, `38/38` deep covers via Yosys `sim -assert` on lowered `prove` model; `52/52` total core covers); `audit_formal.py` `40/40` tasks PASS |
| Bus owner, native bus, native core | Pass |
| Directed bootstrap suite (`run_sim.sh`) | Pass, including the #284 tests |
| Instruction vectors (`run_vectors.sh`) | `99,650` cases, `1,715,162` states pass against Unicorn 2.1.4 |
| Physical Harris-286 captures (`run_hardware.sh`) | Pinned SingleStepTests/80286 (`37c73ca`) MOO captures replay exact |
| Gate mutation suites | Undefined-opcode (4), protection (4), protected-event (6) and protected-string (15) mutants all caught (`29/29`) |
| IBM AT BIOS (`run_software.sh`) | `196,846` instruction states match Unicorn to `F000:0225`; timer, DMA, page-register and refresh checks pass |
| PCE-286 oracle (`run_pce_oracle.sh`) | `3,019` scenarios: `2,926` pass, `93` waived with citations, `0` mismatch |
| Synthesis (`run_synth.sh`, Yosys `check -assert`) | All `13` targets pass (`intel_80286` `71,624` cells / `744.28 s`; `intel_80286_native_beats` `71,042` cells / `787.24 s`; `intel_80286_native_cpu` `72,285` cells / `764.42 s`) |

Total single-pass wall time: `12,907 s` (`3 h 35 m 07 s`).

## Known issues and limits

- **Assumptions needing silicon.** A47 (near transfers beyond the CS limit)
  is settled with PCE-286 only; A48 (shadows across WAIT) is a choice the
  review left to the owner; A31 rests on Appendix B where the manual
  contradicts itself. None is confirmed on a physical 286.
- **Finding 11** was confirmed fixed with the pinned Verilator only; the
  newer build the review used was not run.
- **Standalone mutation suites outside the gate.** All `16` mutation suites
  (`119` patterns, including the 7 component suites added to
  `scripts/check_mutation_patterns.py`) now pass target pattern checks cleanly;
  standalone runtime mutation scripts outside `run_all.sh` remain separate from
  the release-gate execution path.
- **Oracle waivers.** 93 PCE-286 differences are waived, each with a cited
  reason; four are for finding 3 (PCE-286 applies the 386 #TS rule).
- **Remaining full-chip `#80` scope.** OS/2 SDK 1.00 `CPGREP.EXE` RTL trace,
  remaining protected-mode/ISA combinations, native timing/pin behavior, and
  attached-80287 validation remain open as listed in
  [the completion requirements](../plans/completion_requirements.md).
