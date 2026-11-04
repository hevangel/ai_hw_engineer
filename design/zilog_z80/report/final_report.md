# Final design report: Zilog Z80

## 1. Executive summary

**Milestone: specification.** This folder currently contains the source-backed
specification, the implementation, test and formal plans, and the source and
oracle provenance record. There is no RTL, testbench, formal property or
synthesis result yet. Nothing in this design has been simulated, proved,
synthesized or run against an oracle, and no implementation claim is made.

The design index therefore describes this entry as being in its specification
phase, matching the repository rule that scaffolding is not implementation.

## 2. Design overview

- Module (planned): `zilog_z80` functional transaction-bus top,
  `zilog_z80_native` pin-level top sharing the same core
- Target: Zilog NMOS Z80 (Z8400 family, 2.5/4/6/8 MHz grades), 40-pin DIP
- Scope: full documented ISA, the undocumented encodings that compatibility
  suites exercise, three interrupt modes, NMI, HALT, DRAM refresh
- Out of scope: electrical/analog behavior, CMOS-only differences, Z180/Z280/
  eZ80 extensions, TRS-80 board integration (dependent system issue)
- Date: 2026-11-04 (specification milestone)

## 3. Verification status

No verification tool has been run. This is not a pass; it is the absence of any
artifact to check.

| Gate | Status | Reason |
|---|---|---|
| Verilator lint | Not run | no RTL exists |
| Formal (bmc/prove/cover) | Not run | no properties or `.sby` exist |
| Simulation / UVM | Not run | no testbench exists |
| Oracle differential | Not run | oracle not yet vendored |
| ZEXDOC / ZEXALL / z80test | Not run | exercisers not yet obtained |
| Historical software | Not run | no RTL, no CP/M harness yet |
| Synthesis | Not run | no RTL exists |
| Native timing comparison | Not run | native engine not started |

The `scripts/` directory holds the repository's scaffolded entry points
(`run_all.sh`, `run_formal.sh`, `run_sim.sh`, `run_coverage.sh`,
`run_synth.sh`) unchanged from `design/_template/`. They skip formal and
simulation when no sources exist and have not been exercised by this design.

## 4. Known issues and limitations

| Item | Impact | Status |
|---|---|---|
| Undocumented F3/F5 table not yet extracted | RTL flag contract undefined | Phase-0 task |
| Oracle not vendored | no independent check yet | Phase-0 task |
| `OUT (C),0` data byte (NMOS 0xFF vs CMOS 0x00) | pin-level data value | open assumption, ledger row |
| R increment on interrupt acknowledge | refresh counter value | open assumption, ledger row |
| NMOS minimum clock frequency | sub-minimum-clock behavior | open, native engine boundary |
| Timing tables are 2016 reformatting until a dated manual is pinned | pin-level citations | phase-0 mitigation |

## 5. Open items mapped to the issue's acceptance criteria

- [ ] Source-backed specification and assumption ledger — **specification
      written**; assumption rows still open
- [ ] Implementation plan and synthesizable SystemVerilog — plan written; RTL
      absent
- [ ] Independent oracle and real historical software — plan and provenance
      recorded; nothing obtained or run
- [ ] Lint, simulation, formal with reachable covers, synthesis — none run
- [ ] Native timing, analog approximations and physical validation qualified —
      boundaries stated, nothing measured

## 6. Sign-off

| Criterion | Status |
|---|---|
| RTL frozen | no RTL |
| Formal clean | not run |
| Simulation coverage met | not run |
| Lint clean | not run |
| Synthesis clean | not run |

This report is replaced as milestones land; each entry will cite the exact
command, input hashes and observed output.
