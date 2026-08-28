# Final Design Report: Intel 4004

## 1. Executive summary

The Intel 4004 — the first commercially available microprocessor (MCS-4,
announced November 15, 1971) — is implemented as a single-clock synthesizable
functional reconstruction. All 46 instructions of the implemented repertoire
(the MCS-4 manual's 45, plus the WPM program-memory write documented for
4008/4009 systems) are complete: the 8-period instruction cycle with
multiplexed 4-bit bus operation, the 12-bit program counter in the
four-register circular push-down stack, the sixteen index registers with pair
addressing, BCD arithmetic support, SRC/DCL memory and bank selection, the
ROM I/O ports, and the documented page-straddle, stack-overflow, and
undefined-opcode behaviors.

Strict lint passes without warnings. A 165,778-cycle xezim regression
compares 20,192 instruction boundaries of architectural state against an
independent instruction-set simulator with zero mismatches, exercises all 46
instructions, and includes a fixed-seed random stress phase. Formal
verification proves the complete ISA transition function for every opcode
encoding and start state (bounded and unbounded), all sequencer and bus
safety properties, and 59/59 reachability covers. Yosys generic synthesis
reports zero structural problems and 1,539 cells.

## 2. Design overview

- Module: `intel_4004`
- Version: 1.0
- Validation date: 2026-08-27
- Language: SystemVerilog IEEE 1800-2017
- Bus: 4-bit multiplexed address/instruction/data bus as separate
  `data_i`/`data_o`/`data_oe`
- Command lines: `sync`, `cm_rom`, bank-decoded `cm_ram[3:0]`
- Clock/reset: single `clk` (one clock per historical clock period) with a
  synchronous active-low `rst_n` (reconstruction additions, documented in
  spec sections 3.2 and 6.4)

The historical part runs two non-overlapping clock phases and an asynchronous
RESET pin; this core advances one internal phase per `clk` edge and commits
all architectural state on the single edge that ends the instruction's final
X3. The program counter is held frozen at the fetched word and the advanced
value (PC+1 per instruction cycle) is applied at the commit edge, which
reproduces the historical increment-at-A1 page quirks of JCN/JIN/FIN/ISZ
exactly while keeping one provable commit point.

## 3. Reproducible toolchain

| Tool | Validated version/revision |
|---|---|
| Verilator | 5.050, revision `3d2421f3` |
| Verible | `v0.0-4148-g1ea007ec` |
| xezim | 0.10.3, revision `66efe06` |
| Yosys | 0.46, revision `e97731b9d` |
| SymbiYosys | v0.68 |
| Z3 / ABC | image default |

All validation commands ran in image ID:

```text
sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147
```

## 4. Verification results

### 4.1 Lint

| Check | Command summary | Result |
|---|---|---|
| RTL | `verilator --lint-only -Wall` | PASS, zero warnings |
| RTL + timed testbench | `verilator --lint-only -Wall --timing` | PASS, zero warnings |
| Authored RTL/TB/formal sources | `verible-verilog-lint` | PASS, zero violations |

### 4.2 Simulation

The self-checking bench (`tb/tb_intel_4004.sv`) simulates a complete MCS-4
microsystem: behavioral 4001 ROM (program store, per-chip I/O ports, WPM
program-memory shadow) and 4002 RAM (main memory, status characters, output
ports) models respond on the multiplexed bus per spec section 6, while an
independent instruction-set simulator with its own shadow memories steps one
instruction per commit. The bench compares every architectural register
(program-counter stack, accumulator, carry, all sixteen index registers, SRC
pointer, command register) at every instruction boundary, and every bus
signal (`data_o`/`data_oe`/`sync`/`cm_rom`/`cm_ram`) at every clock, against
expectations derived from the reference model.

```text
4004 simulation result: 165778 cycles, 20192 instruction boundaries
Phase A boundaries: 12000 (46/46 instructions seen), Phase B boundaries: 8192
TEST PASSED
```

The directed program covers reset, every instruction with its corner values
(ADD/SUB/ADM/SBM carry and borrow cases under the inverted-carry subtract
convention, DAA adjust/no-adjust paths, TCS both values, KBP across all
inputs, carry rotations), all 16 JCN condition codes, 3-deep JMS/BBL nesting,
the documented 4-JMS stack overflow and unwinding, ISZ taken and skip paths,
FIN/JIN indirect control, DCL bank selection (values 1, 2, 3, and 7),
SRC-selected RAM main/status/output and ROM-port operations, WPM, the
undefined-opcode NOPs, and the page-straddle quirk zones (a two-word ISZ
straddling words 254/255 so its branch page is the post-increment page, and a
FIN at word 255 fetching through the rolled page). The testbench fails the
run if any of the 46 defined instructions is never executed. A fixed-seed
random program adds 8,192 further compared boundaries. Final memory images
match the reference model exactly.

Result: **PASS**.

### 4.3 Formal verification

The property module embeds a golden instruction-set simulator written from
spec sections 5-6. Bus assumptions deliver `anyconst` instruction words at
M1/M2 and `anyconst` memory data at X3; the golden model and the DUT are
asserted equal on every architectural register at every clock, for every
opcode encoding and every start state — proving the complete ISA transition
function rather than sampled cases. Additional properties re-derive every
output combinationally, check sequencer validity, and confirm fetch-latch
equivalence. Reset is assumed only in the initial cycle; later reset and all
free inputs remain unconstrained, and the golden model mirrors reset
semantics.

| Task | Engine | Result |
|---|---|---|
| BMC | ABC `bmc3`, 24 frames | PASS, no assertion reached |
| Unbounded proof | ABC `pdr` | PASS, converged in 15 s |
| Cover | `smtbmc --unroll z3`, depth 120 | PASS, 59/59 covers reached |

The cover task demonstrates reachability for every OPR group, the FIM/SRC/
FIN/JIN variants, ten RAM/ROM I/O representatives including WPM and the
reserved-as-NOP encodings, all fourteen accumulator-group encodings, both
JCN and ISZ branch outcomes, stack-full and SRC-pointer states, DCL bank
registers, `cm_ram` drive, ROM-port drive, page-edge second-word fetch, and
the TEST-pin condition.

### 4.4 Synthesis

Yosys generic synthesis completes with no inferred latches, no memories, no
remaining processes, and zero `check` problems.

```text
Number of cells: 1539
  $_AND_ 489, $_MUX_ 396, $_OR_ 336, $_DFFE_PP_ 112, $_XOR_ 84,
  $_NOT_ 86, $_DFF_P_ 2, $_SDFFE_PN0P_ 25, $_SDFF_PN0_ 6, $_SDFF_PP0_ 3
```

## 5. Known deviations and interpretations

- **SBM/SUB carry sense (spec 5.7):** both subtracts add the inverted carry
  (`ACC + ~operand + ~CY`, CY = 1 = no borrow), following the manual's SBM
  equation and hardware-validated implementations; the manual's printed SUB
  equation omits the inversion. Documented rather than silently resolved.
- **DCL multi-line decode (spec 5.3):** line 0 with no command bits set,
  lines 1-3 following command-register bits 0-2. The single-line rows match
  the manual's table; the combination rows for expanded banks are corrupted
  in the surviving documentation, so the chosen decode is stated explicitly.
- **WPM bus context (spec 11):** the ACC half-byte is driven at X2-X3 with
  `cm_rom` asserted; 4008/4009 chip-select and half-byte lane mechanics are
  memory-side behavior.
- **X2/X3 I/O windowing (spec 6.3):** write-type operations drive ACC during
  X2 and X3 with memory latching at the end of X3; read-type operations are
  sampled at the end of X3. The historical parts qualify command lines at M2
  and perform some ROM I/O at X2; exact phase placement of I/O data is out
  of scope (spec 11) and the chosen contract is uniform and specified.
- **PC update style (implementation plan):** the program counter is written
  exactly once per commit from a combinational `pc_next`; multiple
  non-blocking assignments to the same array element within one evaluation
  are avoided because the project simulator resolves them first-write-wins
  while IEEE semantics (and Yosys) resolve last-write-wins.

## 6. Conclusion

The Intel 4004 reconstruction implements the complete MCS-4 programming model
and bus protocol with every behavior traced to the scanned MCS-4 manual or
explicitly documented as a reconstruction choice. Lint, deterministic
simulation against an independent reference model, formal proof of the full
ISA transition function with non-vacuity covers, and generic synthesis all
pass. The design is ready for review.
