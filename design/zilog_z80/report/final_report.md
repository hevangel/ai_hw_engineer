# Final design report: Zilog Z80

## 1. Executive summary

**Milestone 2: byte ALU implemented and differentially verified.** The folder
contains the source-backed specification, the implementation, test and formal
plans, the source and oracle provenance record, the vendored pinned oracle, and
the first RTL unit: `src/zilog_z80_alu.sv` with `src/zilog_z80_pkg.sv`.

The ALU matches the independent superzazu/z80 emulator over 648,328 cases with
0 mismatches, and the harness' negative control rejects all 648,328 cases after
a one-bit expectation flip. The instruction sequencer, top-level bus interface,
testbench for whole instructions, formal properties and synthesis are **not yet
implemented**; no whole-instruction, exerciser, software or synthesis claim is
made.

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

| Gate | Status | Reason |
|---|---|---|
| ALU differential vs pinned oracle | **PASS**, 648,328 cases, 0 mismatches | `scripts/run_alu.sh`, Verilator 5.052 in the project tool image |
| ALU negative control | **PASS**, 648,328/648,328 rejected | `run_alu.sh --negative-control` |
| Verilator lint (whole core) | Not run | core top does not exist yet |
| Formal (bmc/prove/cover) | Not run | no properties or `.sby` exist |
| Instruction simulation / UVM | Not run | no instruction-level testbench exists |
| ZEXDOC / ZEXALL / z80test | Not run | exercisers not yet obtained |
| Historical software | Not run | no CP/M harness yet |
| Synthesis | Not run | no synthesizable top yet |
| Native timing comparison | Not run | native engine not started |

The `scripts/` directory holds the repository's scaffolded entry points
(`run_all.sh`, `run_formal.sh`, `run_sim.sh`, `run_coverage.sh`,
`run_synth.sh`) unchanged from `design/_template/`. They skip formal and
simulation when no sources exist and have not been exercised by this design.

## 4. Known issues and limitations

| Item | Impact | Status |
|---|---|---|
| Instruction sequencer and bus top absent | only the ALU is verified end to end | next milestone |
| DAA verified in context only | standalone DAA after an arbitrary F byte is undefined hardware behavior (internal carry/half-carry latches); the harness drives a real ADD/SUB first | documented limitation |
| Undocumented F3/F5 table not yet extracted for the whole ISA | per-opcode contract for the sequencer | phase-0 task |
| ZEXALL/ZEXDOC/z80test not yet obtained | no exerciser gate | phase-0 task |
| `OUT (C),0` data byte (NMOS 0xFF vs CMOS 0x00) | pin-level data value | open assumption, ledger row |
| R increment on interrupt acknowledge | refresh counter value | open assumption, ledger row |
| NMOS minimum clock frequency | sub-minimum-clock behavior | open, native engine boundary |
| Timing tables are 2016 reformatting until a dated manual is pinned | pin-level citations | phase-0 mitigation |

## 5. Open items mapped to the issue's acceptance criteria

- [ ] Source-backed specification and assumption ledger — **specification
      written**; assumption rows still open
- [ ] Implementation plan and synthesizable SystemVerilog — plan written; ALU
      implemented and verified, sequencer and top absent
- [ ] Independent oracle and real historical software — oracle vendored and in
      use for the ALU; exercisers and software not yet run
- [ ] Lint, simulation, formal with reachable covers, synthesis — none run for
      the core
- [ ] Native timing, analog approximations and physical validation qualified —
      boundaries stated, nothing measured

## 6. Sign-off

| Criterion | Status |
|---|---|
| RTL frozen | no; ALU only |
| Formal clean | not run |
| Simulation coverage met | not run |
| Lint clean | not run for the core |
| Synthesis clean | not run |

This report is replaced as milestones land; each entry will cite the exact
command, input hashes and observed output.
