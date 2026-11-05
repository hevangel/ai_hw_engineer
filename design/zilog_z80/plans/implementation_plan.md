# Zilog Z80 implementation plan

1. **Pin the sources before writing RTL.** Vendor UM008011-0816, Sean Young's
   Undocumented Z80 Documented v0.91, the z80.info undocumented-instruction and
   flag-affection pages, and the Z80 timing tables into `references/` with
   SHA-256 hashes, the way the 8080 design pins its manuals. Extract the
   per-opcode flag and T-state tables into a machine-readable file and hash it;
   the RTL contract and the tests both read that file, so a disputed flag is
   changed in one place and re-diffed against the oracle.
2. **Vendor the independent oracle.** Use the unmodified MIT-licensed
   [superzazu/z80](https://github.com/superzazu/z80) emulator (C99, `z80.c` /
   `z80.h`, passes both zexdoc and zexall) at a pinned commit under
   `references/superzazu_z80/`, keeping its license and recording hashes. It is
   the same author already trusted for the 8080 oracle; it supplies exact
   post-instruction register, flag, memory and I/O state. Its cycle counts are
   instruction-level only, so it cannot verify M-cycle timing — the native
   engine needs the UM0080 tables as its timing oracle.
3. **Obtain the exercisers legally.** ZEXDOC.COM and ZEXALL.COM (Frank D.
   Cringle, GPL-2.0, extracted from YAZE-AG 2.51.1) are downloaded into ignored
   `work/` with recorded hashes and are never committed, matching how GPL 6502
   test sources are kept out of the tree. Patrik Rak's z80test suite is added
   for the MEMPTR/WZ behavior ZEXALL cannot see, after its license is recorded.
   The CP/M console/BDOS harness around them is our own bytes and is documented
   separately from the exerciser image.
4. **Functional core, documented set first.** `zilog_z80_pkg` (flag and
   encoding constants), `zilog_z80_alu` (byte ALU with documented and
   undocumented flag sources, DAA, rotates, shifts including SLL),
   `zilog_z80_regfile` (main and alternate files, IX/IY, SP/PC, I, R, WZ),
   `zilog_z80_decoder` (prefix pages, M-cycle sequencing requests) and
   `zilog_z80` (transaction-bus top). Every opcode in the primary page and the
   CB/ED/DD/FD pages retires exactly once with a defined next PC.
5. **Undocumented encodings next, as a separate reviewable commit.**
   IXH/IXL/IYH/IYL, DD-CB register copies, ED duplicates, prefix-ignore rules,
   `ED 70`/`ED 71`, and the Q-latch/WZ flag rules. Each row of the assumption
   ledger gets an `ASSUMPTION:` comment where the RTL implements a provisional
   reading.
6. **Build the oracle bridge and differential corpus.** A C harness links the
   pinned emulator and our RTL through a common trace: for each
   (opcode, operands, initial state) case, compare A/F/B/C/D/E/H/L, alternates,
   IX/IY/SP/PC/I/R/WZ, IFF, IM, every memory write and every I/O access. Bias
   the case set toward the flag-table edges (half carry, overflow, N flag,
   F3/F5 sources, `ADC/SBC HL`, block-instruction end states).
7. **Run the independent exercisers and historical software.** ZEXDOC first
   (documented flags), then ZEXALL (adds undocumented flags), then z80test for
   MEMPTR, then real CP/M 2.2 software through the same bus. Every exerciser
   run records its exact binary hash, console transcript and instruction count.
   These run from `scripts/run_all.sh`, not from a side script that can rot.
8. **UVM and directed tests for control behavior.** Interrupts (NMI, IM 0/1/2,
   `EI` delay, `HALT` exit, IFF dance), reset, R increment rules, prefix
   stacking, `BUSRQ`/`WAIT` at the native boundary. Every instruction test
   asserts the exact post-instruction PC and the next executed instruction;
   padding that absorbs an unknown PC landing is a test defect, not a pass.
9. **Formal proof and reachable covers.** Combinational ALU equivalence against
   the oracle's published helper equations for all 2^16 operand pairs of the
   flag-critical operations; decoder totality (every byte of every page maps to
   a defined instruction); transaction-contract properties (no state advance
   without acknowledgement, stable request payload while stalled, one write per
   write transfer); reachable covers for each page, each interrupt mode, each
   block-instruction phase, HALT entry/exit and the refresh cycle.
10. **Native engine.** `zilog_z80_native` wraps the same core with pin-level
    M-cycle generation: M1 with refresh (R on A0–A6, A7 = 0, IFF2 on A15),
    3-T memory cycles, 4-T I/O with its automatic wait, 6-T interrupt
    acknowledge, `WAIT` sampling at T2 falling edge, `BUSRQ`/`BUSACK` float and
    `HALT` refresh continuation. Verify cycle shapes and T-state counts against
    the extracted UM0080 tables instruction by instruction, with the
    instruction-level oracle used only for architectural state.
11. **Synthesis and handoff.** Lint with `verilator --lint-only -Wall`, generic
    Yosys synthesis plus a conservative FPGA target, and record area and
    warnings. Write `report/final_report.md` with actual commands, observed
    counts, pass/fail per gate and explicit open limitations. The TRS-80 Model I
    system integration is the dependent issue's work; this design supplies the
    core, the native bus and the evidence it needs.

Module hierarchy:

```
zilog_z80            (functional top: transaction bus, retire/fault)
├── zilog_z80_pkg    (types, encodings, flag constants)
├── zilog_z80_decoder(prefix decode, micro-op sequencing)
├── zilog_z80_alu    (byte ALU, rotates, DAA, flag generation)
└── zilog_z80_regfile(main/alternate registers, IX/IY, SP/PC, I, R, WZ)

zilog_z80_native     (pin-level top, same core, M-cycle generator)
└── zilog_z80_core   = decoder + alu + regfile shared with zilog_z80
```

Design decisions:

| Decision | Choice | Rationale |
|---|---|---|
| Staging | Functional engine first, native engine second | Matches the 6502 design; keeps ISA risk separate from timing risk |
| Oracle | superzazu/z80, pinned and unmodified | Independent of our RTL, already the family's MIT reference author |
| Timing source | UM0080 tables, extracted and hashed | The oracle cannot see M-cycles |
| Undocumented flags | Generated table, not hand-written logic per opcode | One reviewable artifact; ZEXALL and z80test check our reading |
| Prefix rules | Decode-time state machine, not per-opcode hacks | Multiple-DD and ED-ignore rules fall out of one model |

Dependencies: no other design folder. The oracle is shared by path, not copied.
The dependent TRS-80 Model I system consumes `zilog_z80_native`; it must not
reach into the functional engine for pin behavior.

## Milestones

| Milestone | Evidence required | Status |
|---|---|---|
| Sources pinned | hashes in `references/README.md` | Not started |
| Flag/timing tables extracted | hashed table file + review | Not started |
| Functional core, documented set | lint clean, per-page opcode tests | Not started |
| Undocumented set | assumption rows fulfilled, ZEXALL pass | Not started |
| Oracle differential | zero mismatches over the corpus, negative control fails | Not started |
| Real software | CP/M 2.2 software transcript + hash | Not started |
| Formal | bmc/prove/cover all pass, covers reachable | Not started |
| Native timing | per-instruction cycle-shape comparison | Not started |
| Synthesis and report | tool logs, area, honest limitations | Not started |
