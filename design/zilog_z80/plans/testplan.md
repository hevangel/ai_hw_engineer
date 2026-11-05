# Zilog Z80 test plan

## Overview

The Z80 is a processor with an independent instruction-stepped oracle
(superzazu/z80), two independent exercisers (ZEXALL/ZEXDOC for ISA and flags,
z80test for MEMPTR) and a large body of historical CP/M software. The plan uses
that external evidence first and our own assertions second, because
per-instruction agreement against a reference model we wrote from our own RTL
would only prove internal consistency.

## Verification goals

- Every encoding in the primary, CB, ED, DD, FD and composite pages executes
  with the documented and undocumented semantics the sources specify.
- Exact post-instruction architectural state: registers, alternates, IX/IY,
  SP/PC, I, R, WZ-derived flags, IFF, IM.
- Exact memory and I/O effects: every write, every read address, every port.
- Exact next fetched instruction and PC after each retirement; no test may
  place padding bytes to absorb an unknown landing.
- Interrupt behavior (NMI, IM 0/1/2, `EI` delay, `HALT`) and reset behavior.
- Native engine: per-instruction M-cycle shape, T-state count, refresh address
  composition, `WAIT` stretching, `BUSRQ`/`BUSACK` and interrupt acknowledge.
- Non-vacuity: every claim has a reachable cover or a positive run.

## Testbench architecture

```
tb_top (directed + oracle differential, functional bus)
  ├── zilog_z80_if        (transaction bus + architectural observation)
  ├── zilog_z80_oracle    (DPI-C bridge to pinned superzazu/z80)
  ├── memory model        (64 KiB RAM with per-cycle access log)
  ├── io model            (256 ports, access log, programmable vector byte)
  └── interrupt driver    (NMI/INT injection, IM-aware vector supply)

tb_native (cycle-shape comparison)
  └── pin monitor         (M1/MREQ/IORQ/RD/WR/RFSH/WAIT/BUSRQ trace)

uvm environment (control-behavior stress)
  └── agent → driver/monitor/sequencer, scoreboard, coverage collector
```

## Test categories

### Directed ISA tests (P1)

| Test | Description | Assertion |
|---|---|---|
| `opcode_page0` | every primary-page byte | state diff vs oracle, exact next PC |
| `opcode_pagecb` | CB page incl. SLL | flags incl. F3/F5 |
| `opcode_pageed` | ED page incl. duplicates, `ED 70`/`ED 71` | registers, flags, port access log |
| `opcode_pagedd_fd` | DD/FD incl. IXH/IXL halves | operand targets |
| `opcode_ddcb_fdcb` | composite page incl. register copies | memory op + copy target |
| `prefix_rules` | DD DD, ED CB, ED DD, FD ED sequences | documented ignore/replace behavior |
| `flags_half_carry` | add/subtract half-carry grid | H, N, F3/F5 |
| `flags_overflow` | signed overflow grid | P/V |
| `daa_grid` | all A/N/H/C combinations | A, all flags |
| `block_end_states` | terminal iteration of each block instruction | PC, B/C, F3/F5 |

### Oracle differential (P1)

Deterministic corpus: for each opcode, all documented operand variants, seed
states chosen to exercise carry/borrow/parity edges, plus random states with a
fixed seed. Compare the full architectural tuple, every memory write and every
I/O access against the pinned emulator. A negative control (one deliberately
wrong flag bit) must fail the comparison, proving the harness can detect
drift.

### Independent exercisers (P1)

| Exerciser | What it proves | Source of bytes |
|---|---|---|
| `prelim.com` | basic decode/ALU smoke | downloaded to ignored `work/`, hash-checked |
| ZEXDOC | documented ISA semantics under CP/M | GPL-2.0 binary kept out of the tree, `work/` only |
| ZEXALL | documented **and undocumented** flags | same |
| z80test | MEMPTR/WZ flag leakage, interrupt edge cases | pinned release, license recorded before use |

### Real historical software (P1, mandatory for a processor)

CP/M 2.2 built software executed through the same bus: the exercisers above
are period-authentic Z80/CP/M binaries, and at least one application-class
program (an assembler or BASIC interpreter obtainable legally, provenance and
hash recorded in `references/README.md`) runs a scripted transcript. Output text
and memory images are compared, not just "it did not crash". The TRS-80 Model I
ROM is copyright Tandy: when the dependent system issue needs it, it is obtained
by the user under the documented provenance manifest and lives in ignored
`work/`; no ROM bytes are committed here.

### Control behavior (P1)

| Test | Description |
|---|---|
| `int_mode0/1/2` | vector formation, IFF clear, RETN/RETI restore, R increment |
| `nmi_priority` | NMI wins over INT, `0x0066` entry, IFF2 preservation |
| `ei_delay` | exactly one instruction executes after `EI` before acceptance |
| `halt_exit` | PC frozen, refresh continues, exit on interrupt |
| `reset_contract` | PC/I/R zeroed, IFF cleared, IM 0, registers undefined-but-deterministic |
| `r_increment` | one per M1 fetch including prefixes, bit 7 preserved |

### Native timing (P1 for the native engine)

Per instruction, compare the pin trace against the extracted UM0080 table:
number of M-cycles, T-states per cycle, address/data valid windows, refresh
address composition and A15 = IFF2, `WAIT` extension count, I/O automatic
wait, interrupt acknowledge shape, `BUSACK` float behavior. `HALT` must keep
issuing refresh cycles. Any instruction whose trace is unmatched is a failure,
not an approximation.

## Coverage plan

| Covergroup | Description | Target |
|---|---|---|
| `cg_page` | every page and prefix combination executed | 100% |
| `cg_opcode` | every opcode retired | 100% |
| `cg_flag` | each flag observed 0 and 1 per relevant instruction class | 100% |
| `cg_prefix` | legal and ignored prefix sequences | 100% |
| `cg_interrupt` | each IM, NMI, EI delay, HALT exit | 100% |
| `cg_native_cycle` | each M-cycle shape incl. refresh and wait states | 100% |

Code coverage targets are secondary to the cross-checked state comparison; line
coverage below 95% or any unreached opcode blocks sign-off.

## Regression strategy

- Smoke: directed page tests + prelim, every commit.
- Full: oracle differential + ZEXDOC + ZEXALL + real software, every commit
  that touches RTL (`run_all.sh`).
- Native: timing comparison on every native-engine change.
- Formal: bmc/prove/cover on every ALU or decoder change.

## Pass/fail criteria

- Zero mismatches against the oracle over the corpus.
- ZEXDOC, ZEXALL and z80test report `OK` on every subtest; console transcript
  recorded verbatim.
- No `UVM_ERROR`/`UVM_FATAL`; scoreboard clean.
- All covers reachable; no vacuous formal proof.
- Native traces match the timing tables exactly, or the gap is recorded as an
  open gate in the report.
