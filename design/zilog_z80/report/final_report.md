# Final design report: Zilog Z80

## 1. Executive summary

**Milestone 4: memory and stack instructions added; core still clean against the
oracle.** The folder contains the source-backed specification, the plans, the
provenance record, the vendored pinned oracle, and these RTL units:
`src/zilog_z80_pkg.sv`, `src/zilog_z80_alu.sv` and `src/zilog_z80.sv`
(transaction-bus core with fetch, prefix handling, decode, memory cycles and
stack sequences).

Two independent gates pass against the pinned superzazu/z80 emulator:

- Byte ALU: 648,328 cases, 0 mismatches; negative control rejects
  648,328/648,328 perturbed cases.
- Instruction core: 1,996 instruction executions compared with full-state **and
  full 64 KiB memory-image** comparison, 0 mismatches; 5 encodings fault as
  designed (I/O and the DD/ED/FD prefix pages).

**Implemented:** NOP; LD r,r'; LD r,n; LD rr,nn; LD r,(HL); LD (HL),r;
LD (HL),n; LD A,(BC)/(DE); LD (BC)/(DE),A; LD A,(nn); LD (nn),A; LD HL,(nn);
LD (nn),HL; LD SP,HL; ALU A,r and A,n and A,(HL); INC/DEC r, rr and (HL);
ADD HL,rr; DAA; CPL; SCF; CCF; RLCA/RRCA/RLA/RRA; JR/JR cc/DJNZ; JP nn/
JP cc,nn/JP (HL); PUSH/POP incl. AF; CALL nn/CALL cc/RET/RET cc/RST;
EX AF,AF'/EX DE,HL/EXX/EX (SP),HL; DI; EI; HALT; and the CB page on registers
and on (HL) for rotate/shift/RES/SET.

**Not implemented:** BIT n,(HL) (its undocumented F3/F5 source is the WZ
register), the ED page, the DD/FD index pages, block instructions, I/O, and
interrupt entry. Those raise `fault_o` instead of executing wrongly.

**Formal and synthesis gates now pass for the implemented subset:** SBY bmc
(depth 40) PASS, cover (depth 60) PASS with all six cover points reached, and
prove PASS by k-induction; Yosys 0.69 synthesizes the core to 16,179 generic
cells. ZEXDOC/ZEXALL and real historical software remain open because they need
the ED and index pages.

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
| Instruction differential | **PASS**, 1,996 compared, 0 mismatches, 5 unimplemented | `scripts/run_instr.sh` (state + full memory image) |
| Verilator lint (core) | No errors; 18 `-Wall` warnings (unused interrupt inputs, reserved parameters) | `verilator --lint-only -Wall` |
| Formal bmc | **PASS**, depth 40 | `sby -f formal/zilog_z80.sby bmc` |
| Formal cover | **PASS**, all 6 cover points reached | `sby -f formal/zilog_z80.sby cover` |
| Formal prove | **PASS** by k-induction | `sby -f formal/zilog_z80.sby prove` |
| Synthesis (generic) | **PASS**, 16,179 cells, 264 flops | `scripts/run_synth.sh generic`, Yosys 0.69 |
| Formal (bmc/prove/cover) | Not run | no properties or `.sby` exist |
| UVM environment | Not run | not written |
| ZEXDOC / ZEXALL / z80test | Not run | needs memory/stack instructions first |
| Historical software | Not run | needs CALL/RET/stack and CP/M harness |
| Synthesis | **PASS** (generic cells; no timing or area target set) | `scripts/run_synth.sh generic` |
| Native timing comparison | Not run | native engine not started |

The `scripts/` directory holds the repository's scaffolded entry points
(`run_all.sh`, `run_formal.sh`, `run_sim.sh`, `run_coverage.sh`,
`run_synth.sh`) unchanged from `design/_template/`. They skip formal and
simulation when no sources exist and have not been exercised by this design.

## 4. Known issues and limitations

| Item | Impact | Status |
|---|---|---|
| BIT n,(HL) absent (WZ-sourced F3/F5) | one CB form faults | next milestone |
| ED page, DD/FD index pages, block instructions, I/O, interrupt entry absent | these encodings fault | next milestones |
| DAA verified in context only | standalone DAA after an arbitrary F byte is undefined hardware behavior | documented limitation |
| SCF/CCF F3/F5 from A, no Q latch | matches the pinned oracle | documented assumption |
| EI delay and interrupt entry not modelled | EI takes effect immediately | documented assumption |
| ZEXALL/ZEXDOC/z80test not yet obtained | exercisers need ED/DD and BIT (HL) | next milestone |
| `OUT (C),0` data byte (NMOS 0xFF vs CMOS 0x00) | pin-level data value | open assumption, ledger row |
| NMOS minimum clock frequency | sub-minimum-clock behavior | open, native engine boundary |

## 5. Open items mapped to the issue's acceptance criteria

- [ ] Source-backed specification and assumption ledger — **specification
      written**; assumption rows still open
- [ ] Implementation plan and synthesizable SystemVerilog — core covers the
      primary page except I/O, plus CB on registers/(HL); ED, DD/FD, block and
      BIT (HL) absent
- [ ] Independent oracle and real historical software — oracle driving both
      differential gates; exercisers and software not yet run
- [ ] Lint, simulation, formal with reachable covers, synthesis — lint clean,
      differential simulation passing, formal bmc/cover/prove passing for the
      implemented subset, generic synthesis clean; full-ISA gates pending
- [ ] Native timing, analog approximations and physical validation qualified —
      boundaries stated, nothing measured

## 6. Sign-off

| Criterion | Status |
|---|---|
| RTL frozen | no; primary page except I/O plus CB memory forms |
| Formal clean | yes for the implemented subset (bmc/cover/prove PASS) |
| Simulation coverage met | differential gates pass; coverage not measured |
| Lint clean | no errors; 18 warnings |
| Synthesis clean | yes, generic; no timing/area target |

This report is replaced as milestones land; each entry will cite the exact
command, input hashes and observed output.
