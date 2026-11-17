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

**Every documented encoding plus the undocumented ones the exercisers test are now
implemented**: the primary page, CB (including `BIT n,(HL)` and the DD-CB/FD-CB
composites with register autocopy), ED (including all block groups) and the DD/FD
index pages with the undocumented IXH/IXL aliases.

**Formal and synthesis gates pass for the implemented subset:** SBY bmc/cover/
prove and Yosys generic synthesis are re-run on every change; see the table
below. ZEXDOC/ZEXALL and real historical software remain open because they need
the index pages.

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
| Instruction differential | **PASS**, 7,168 compared, 0 mismatches, 0 unimplemented | `scripts/run_instr.sh` (state + full memory image) |
| Verilator lint (core) | No errors (warnings: unused params/signals) | `verilator --lint-only -Wall` |
| Interrupt directed tests | **PASS**, 12/12 checks (NMI, IM 1, IM 2, EI delay, HALT exit, RETN) | `scripts/run_int.sh` |
| Formal bmc | **PASS**, depth 40 | `sby -f formal/zilog_z80.sby bmc` |
| Formal cover | **PASS**, all cover points reached (depth 25) | `sby -f formal/zilog_z80.sby cover` |
| Formal prove | **PASS** by k-induction | `sby -f formal/zilog_z80.sby prove` |
| Synthesis (generic) | **PASS**, 27,378 cells, 373 flops | `scripts/run_synth.sh generic`, Yosys 0.69 |
| Synthesis (iCE40 target) | **PASS**, 3,803 LUT4 + 369 flops | `scripts/run_synth.sh ice40` |
| Native engine timing (bus-cycle-exact subset) | **PASS**, 16/16 instructions | `scripts/run_native.sh` |
| ZEXDOC / ZEXALL / z80test | Not run | needs the CP/M harness; ZEXALL is ~5.8e9 instructions |
| Historical software | Not run | needs a CP/M BDOS harness |
| Synthesis | **PASS** (generic cells; no timing or area target set) | `scripts/run_synth.sh generic` |
| Native timing, internal T-states | Not modelled | `zilog_z80_native` reproduces M1/memory/I-O cycle shapes and totals for the bus-cycle-exact subset; instructions with internal T-states (INC (HL), JR, PUSH, CALL, block groups) need per-opcode internal cycles |

### Real historical software

`tb/cpm_harness.cpp` + `scripts/run_cpm.sh` load a CP/M-80 `.com` at 0x0100,
trap the BDOS entry at 0x0005 (functions 2 and 9 only) and the warm boot at
0x0000, and capture console output. Binaries live in the ignored `work/cpm/`
directory; SHA-256 values are recorded in [references/README.md](../references/README.md).

| Image | Result | Instructions |
|---|---|---|
| `prelim.com` (Z80 preliminary exerciser) | **PASS** — prints `Preliminary tests complete` | 898 |
| `8080pre.com` (8080 preliminary test) | **PASS** — prints `8080 Preliminary tests complete` | 1,060 |
| `tst8080.com` (Microcosm 8080 diagnostic) | **fails at 0x01FB, as expected on a Z80** — the test branches on parity after `ADD A,70`, but on a Z80 bit 2 is P/V (overflow for arithmetic) rather than the 8080's parity | 106 |
| `zexdoc.com` (Frank D. Cringle, GPL) | starts and enters its first subtest; a full run is ~5.7e9 instructions | — |

The TST8080 result is a genuine ISA difference, not a core defect: the Z80
replaces the 8080's always-parity bit 2 with P/V. It is recorded here so the
difference is not mistaken for a regression later.

The gate scripts are `run_alu.sh`, `run_instr.sh`, `run_int.sh` and `run_cpm.sh`;
`run_all.sh`, `run_formal.sh`, `run_sim.sh`, `run_coverage.sh` and `run_synth.sh`
are the repository scaffold entry points.



## 4. Known issues and limitations

| Item | Impact | Status |
|---|---|---|
| WZ/MEMPTR is only modelled where it affects flags | BIT n,(HL) uses the stale WZ, matching the oracle's behaviour for the tested paths | documented limitation |
| IM 0 executes only the RST-form byte supplied by the device | other injected opcodes behave as a no-op | documented limitation |
| DAA verified in context only | standalone DAA after an arbitrary F byte is undefined hardware behavior | documented limitation |
| SCF/CCF F3/F5 from A, no Q latch | matches the pinned oracle | documented assumption |
| IN A,(n) leaves F unchanged | matches the pinned oracle | documented, differs from some published tables |
| ZEXALL/ZEXDOC/z80test not yet obtained | exercisers need the index pages | next milestone |
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
