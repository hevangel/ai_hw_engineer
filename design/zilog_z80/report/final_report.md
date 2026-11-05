# Final design report: Zilog Z80

## 1. Executive summary

**Milestone 3: register-execution core implemented and differentially verified.**
The folder contains the source-backed specification, the plans, the provenance
record, the vendored pinned oracle, and these RTL units: `src/zilog_z80_pkg.sv`,
`src/zilog_z80_alu.sv` and `src/zilog_z80.sv` (transaction-bus core with fetch,
prefix handling, decode and the register-only instruction subset).

Two independent gates pass against the pinned superzazu/z80 emulator:

- Byte ALU: 648,328 cases, 0 mismatches; negative control rejects
  648,328/648,328 perturbed cases.
- Instruction core: 1,612 instruction executions compared (each from a
  randomized prologue state, comparing A/F/alternates/BC/DE/HL/SP/PC/R/IFF/IM/
  halt), 0 mismatches; 77 encodings outside this milestone's subset fault as
  designed.

**Not implemented yet:** memory operands `(HL)`/`(BC)`/`(DE)`/`(nn)`, the stack
(PUSH/POP/CALL/RET/RST), IX/IY and the DD/FD pages, the ED page, block
instructions, I/O, and interrupt entry. Those encodings raise `fault_o` instead
of executing wrongly. Formal properties, ZEXDOC/ZEXALL, historical software,
native timing and synthesis are also outstanding and are reported as such.

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
| Instruction differential | **PASS**, 1,612 compared, 0 mismatches, 77 unimplemented | `scripts/run_instr.sh` |
| Verilator lint (core) | Clean, warnings only (unused params/signals) | `verilator --lint-only -Wall` |
| Formal (bmc/prove/cover) | Not run | no properties or `.sby` exist |
| UVM environment | Not run | not written |
| ZEXDOC / ZEXALL / z80test | Not run | needs memory/stack instructions first |
| Historical software | Not run | needs CALL/RET/stack and CP/M harness |
| Synthesis | Not run | top is not yet synthesizable-complete (fault path is fine, subset is not) |
| Native timing comparison | Not run | native engine not started |

The `scripts/` directory holds the repository's scaffolded entry points
(`run_all.sh`, `run_formal.sh`, `run_sim.sh`, `run_coverage.sh`,
`run_synth.sh`) unchanged from `design/_template/`. They skip formal and
simulation when no sources exist and have not been exercised by this design.

## 4. Known issues and limitations

| Item | Impact | Status |
|---|---|---|
| Memory-indirect, stack, CALL/RET/RST, IX/IY, DD/FD, ED, block and I/O instructions absent | the core cannot run a program yet | next milestone; they fault |
| DAA verified in context only | standalone DAA after an arbitrary F byte is undefined hardware behavior (internal carry/half-carry latches); the harness drives a real ADD/SUB first | documented limitation |
| SCF/CCF F3/F5 from A, no Q latch | matches the pinned oracle and the common ZEXALL expectation; hardware Q behavior is a later refinement | documented assumption |
| EI delay and interrupt entry not modelled | EI takes effect immediately | documented assumption |
| Undocumented F3/F5 table not yet extracted for memory/ED forms | per-opcode contract beyond this subset | phase-0 task |
| ZEXALL/ZEXDOC/z80test not yet obtained | no exerciser gate | needs the fuller core first |
| `OUT (C),0` data byte (NMOS 0xFF vs CMOS 0x00) | pin-level data value | open assumption, ledger row |
| NMOS minimum clock frequency | sub-minimum-clock behavior | open, native engine boundary |

## 5. Open items mapped to the issue's acceptance criteria

- [ ] Source-backed specification and assumption ledger — **specification
      written**; assumption rows still open
- [ ] Implementation plan and synthesizable SystemVerilog — register-execution
      core implemented and verified; memory/stack/index/ED pages absent
- [ ] Independent oracle and real historical software — oracle vendored and
      driving two differential gates; exercisers and software not yet run
- [ ] Lint, simulation, formal with reachable covers, synthesis — lint clean;
      formal and synthesis not run
- [ ] Native timing, analog approximations and physical validation qualified —
      boundaries stated, nothing measured

## 6. Sign-off

| Criterion | Status |
|---|---|
| RTL frozen | no; register-execution subset |
| Formal clean | not run |
| Simulation coverage met | differential gates pass; coverage not measured |
| Lint clean | clean with warnings |
| Synthesis clean | not run |

This report is replaced as milestones land; each entry will cite the exact
command, input hashes and observed output.
