# Specification: Intel 4004

## 1. Overview

The Intel 4004 is the first commercially available microprocessor: a 4-bit PMOS
CPU announced by Intel on November 15, 1971 as the central component of the
MCS-4 four-chip family (4001 ROM, 4002 RAM, 4003 shift register), originally
developed for the Busicom 141-PF calculator. The CPU executes the MCS-4
instruction repertoire on 4-bit data, addresses up to 4K words of program ROM
through a 12-bit program counter, and talks to memories over a single 4-bit
bus that multiplexes addresses, instructions, and data across the eight clock
periods of every instruction cycle.

The instruction repertoire is 45 instructions in the MCS-4 manual's own count
(16 machine instructions, 14 accumulator-group, 15 input/output and RAM) plus
the WPM program-memory write the same manual documents for 4008/4009-based
systems, giving the commonly cited total of 46. This design implements all 46.

This specification defines the behavioral contract implemented by
`src/intel_4004.sv`. It is a synchronous, synthesizable functional
reconstruction of the CPU's programming model and bus protocol, not an
electrical, timing-, or transistor-level model of the NMOS part. The historical
chip resets through a level-sensitive asynchronous RESET pin and uses
two-phase non-overlapping clocks; this core samples everything on a single
`clk` and adds a synchronous active-low `rst_n` that establishes a defined
state. Section 11 lists what is deliberately out of scope.

## 2. Features

- Full MCS-4 instruction repertoire: 45 instructions (16 basic, 15 RAM/ROM
  I/O, 14 accumulator-group) plus WPM — the 46-instruction total.
- 12-bit program counter held in a 4-register push-down address stack (program
  counter plus three return addresses, i.e., up to 3-level subroutine nesting)
  with the documented circular-overflow behavior.
- Sixteen 4-bit index registers (eight register pairs), pair 0 doubling as the
  indirect-fetch pointer for FIN/JIN.
- 4-bit accumulator with carry, BCD support via DAA and TCS, and the
  increment/decrement/complement/rotate accumulator group.
- RAM/ROM port I/O instructions with the SRC register-pair pointer protocol and
  the DCL command-line (RAM bank) register.
- The historical 8-period instruction cycle (A1 A2 A3 M1 M2 X1 X2 X3) with
  multiplexed 4-bit bus operation, `sync` pulse at A1, `cm_rom` during A1-A3,
  and bank-decoded `cm_ram` lines during X2-X3 of RAM instructions and SRC.
- The documented page-boundary quirks of JCN, JIN, FIN, and ISZ emerge from
  the faithful PC-increment-at-A1 timing rather than being special-cased.
- Undefined opcode combinations execute as NOPs (documented reconstruction
  choice, consistent with the real decoder's behavior).

## 3. Interfaces

### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | Master clock; one clock per historical clock period |
| `rst_n` | input | 1 | Active-low synchronous reset (reconstruction addition; see 6.4) |
| `test_i` | input | 1 | Historical TEST pin; sampled by JCN condition code C4 |
| `data_i` | input | 4 | Bus nibble driven by memory/IO chips (input half of the 4-bit bus) |
| `data_o` | output | 4 | Bus nibble driven by the CPU (output half of the 4-bit bus) |
| `data_oe` | output | 1 | 1 when the CPU drives the bus (external integration may gate `data_o`) |
| `sync` | output | 1 | Historical SYNC: 1 during A1, the first clock period of every instruction cycle |
| `cm_rom` | output | 1 | ROM command line: 1 during A1-A3 of every instruction cycle |
| `cm_ram` | output | 4 | RAM bank command lines, decoded per DCL; 1 during X2-X3 of RAM instructions and SRC |

The historical D0-D3 bidirectional bus is represented as separate input
(`data_i`), output (`data_o`), and output-enable (`data_oe`) signals, matching
the convention used across this repository. In a pin-accurate integration
`data_o` would be tri-stated by `data_oe` onto a shared wire.

### 3.2 Clock and Phase Generation

The historical part runs on two non-overlapping clocks, φ1/φ2, and defines one
instruction cycle as eight clock periods A1, A2, A3, M1, M2, X1, X2, X3 (two
machine cycles of four periods each). This core takes a single `clk` whose
every rising edge ends one historical clock period, and maintains an internal
3-bit phase counter:

| Phase | Encoding | Historical name |
|-------|----------|-----------------|
| 0 | A1 | SYNC/address low |
| 1 | A2 | address middle |
| 2 | A3 | address high |
| 3 | M1 | opcode nibble (OPR) |
| 4 | M2 | operand nibble (OPA) |
| 5 | X1 | execute |
| 6 | X2 | execute / I/O write |
| 7 | X3 | execute / I/O read |

All architectural commits happen on the single clock edge that ends X3
(phase 7 to 0), which is where memory I/O data is sampled. This uniform
commit rule is a reconstruction choice that preserves the historical
ordering: fetch (M1/M2), bus I/O (X2/X3), then state update.

## 4. Architecture

### 4.1 Registers

| Resource | Width | Reset value | Description |
|----------|-------|-------------|-------------|
| ACC | 4 | 0 | Accumulator |
| CY | 1 | 0 | Carry flag; 1 also means "no borrow" for subtracts |
| R0-R15 | 4 each | 0 | Index registers, accessed singly (RRRR) or as pairs RRR0/RRR1 where RRR selects the pair and the even (RRR0) register holds the high nibble |
| stack[0-3] | 12 each | 0 | Push-down address stack; stack[SP] is the program counter |
| SP | 2 | 0 | Stack pointer into the circular 4-register stack |
| SRC pointer | 8 | 0 | Latched SRC pair content selecting RAM chip/register/character or ROM chip |
| CMD | 3 | 0 | DCL command register selecting the active CM-RAM bank line(s) |

Index registers are deliberately **not** cleared by `rst_n`: the historical
RESET pin does not affect them. Everything else in the table is cleared. The
program counter value is `stack[SP]`; 12 bits address 4096 program words as
{ROM chip 4 bits, ROM word 8 bits}.

### 4.2 Data Flow

Every instruction fetch reads program memory over the shared bus: the CPU
multiplexes the 12-bit program counter out low-nibble-first during A1-A3 (with
`cm_rom` asserted so the ROMs latch it), and the selected ROM drives the two
nibbles of the 8-bit word back during M1 (high, OPR) and M2 (low, OPA).
Instructions that operate on RAM or I/O ports use the SRC pointer latched by
the most recent SRC instruction, and the DCL-selected bank, to read or write a
4-bit value during X2/X3.

### 4.3 Control Logic

The control FSM is {cycle, phase}: `cycle` is 1 or 2, `phase` counts 0-7. All
two-word instructions (JCN, FIM, JUN, JMS, ISZ) and the one-word, two-cycle
exception FIN use two instruction cycles; every other instruction completes in
one. At the end of the final X3 of an instruction the CPU applies the
architectural update for the decoded instruction; the next cycle then fetches
from the updated PC.

## 5. Instruction Set

Words: W = 8-bit word (OPR = high nibble, fetched at M1; OPA = low nibble,
fetched at M2). RRRR selects one of 16 index registers; RRR selects one of
eight register pairs, the pair's even register being the high nibble. C4C3C2C1
is the JCN condition code; DDDD is 4-bit immediate data; A3 is a 4-bit field
of the first word; A2A1 is the 8-bit second word (or the two nibbles of
in-page 8-bit address/data fields).

### 5.1 Basic instructions

| Mnemonic | Encoding | Words | Cycles | Semantics |
|----------|----------|-------|--------|-----------|
| NOP | 0000 0000 | 1 | 1 | No operation |
| JCN | 0001 C4C3C2C1 | 2 | 2 | Jump to {PC[11:8], A2A1} if condition (5.4) true |
| FIM | 0010 RRR0 | 2 | 2 | RRR0 ← A2, RRR1 ← A1 (load pair with immediate) |
| SRC | 0010 RRR1 | 1 | 1 | Send {RRR0, RRR1} on the bus at X2 (high nibble) and X3 (low nibble); latch as SRC pointer (RAM chip [7:6], register [5:4], character [3:0]; also selects ROM chip [7:4] for port I/O) |
| FIN | 0011 RRR0 | 1 | 2 | Fetch ROM word at {PC[11:8], R0, R1} into pair RRR (R0/R1 unchanged only if RRR ≠ 0) |
| JIN | 0011 RRR1 | 1 | 1 | PC[7:0] ← {RRR0, RRR1} (PC[11:8] unchanged) |
| JUN | 0100 A3 | 2 | 2 | PC ← {A3, A2, A1} |
| JMS | 0101 A3 | 2 | 2 | Push return address, then PC ← {A3, A2, A1} (5.5) |
| INC | 0110 RRRR | 1 | 1 | RRRR ← RRRR + 1 (mod 16); CY unaffected |
| ISZ | 0111 RRRR | 2 | 2 | RRRR ← RRRR + 1 (mod 16); if result = 0, skip (PC advances past second word), else PC[7:0] ← {A2, A1} |
| ADD | 1000 RRRR | 1 | 1 | {CY, ACC} ← ACC + RRRR + CY |
| SUB | 1001 RRRR | 1 | 1 | {CY, ACC} ← ACC + ~RRRR + ~CY; CY = 1 means no borrow (see 5.7) |
| LD | 1010 RRRR | 1 | 1 | ACC ← RRRR |
| XCH | 1011 RRRR | 1 | 1 | ACC ↔ RRRR |
| BBL | 1100 DDDD | 1 | 1 | Pop return address into PC; ACC ← DDDD; CY unaffected |
| LDM | 1101 DDDD | 1 | 1 | ACC ← DDDD |

### 5.2 RAM and ROM port instructions

All use OPR = 1110 and operate through the SRC pointer latched by the most
recent SRC, with `cm_ram` lines per the DCL bank register. Write-type
operations drive ACC on the bus during X2 and X3; read-type operations sample
the bus at the end of X3.

| Mnemonic | Encoding | Semantics |
|----------|----------|-----------|
| WRM | 1110 0000 | RAM main character ← ACC |
| WMP | 1110 0001 | RAM output port ← ACC |
| WRR | 1110 0010 | ROM I/O port ← ACC (`cm_rom` context, not `cm_ram`) |
| WPM | 1110 0011 | Program memory half-byte ← ACC (drive ACC at X2/X3, `cm_rom` asserted; used with 4008/4009 RAM-backed program memory) |
| WR0 | 1110 0100 | RAM status character 0 ← ACC |
| WR1 | 1110 0101 | RAM status character 1 ← ACC |
| WR2 | 1110 0110 | RAM status character 2 ← ACC |
| WR3 | 1110 0111 | RAM status character 3 ← ACC |
| SBM | 1110 1000 | {CY, ACC} ← ACC + ~RAM character + ~CY (see 5.7) |
| RDM | 1110 1001 | ACC ← RAM main character |
| RDR | 1110 1010 | ACC ← ROM I/O port |
| ADM | 1110 1011 | {CY, ACC} ← ACC + RAM character + CY |
| RD0 | 1110 1100 | ACC ← RAM status character 0 |
| RD1 | 1110 1101 | ACC ← RAM status character 1 |
| RD2 | 1110 1110 | ACC ← RAM status character 2 |
| RD3 | 1110 1111 | ACC ← RAM status character 3 |

The SRC pointer selects a 4002 RAM chip ([7:6]), one of its four registers
([5:4]), and one of sixteen main characters ([3:0]); status characters are
four per register and are selected entirely by the WR0-WR3/RD0-RD3 opcode, not
by the character field. For WRR/RDR/WPM the pointer's high nibble selects the
ROM chip (or 4008 pair). `cm_ram` is also asserted during X2-X3 of SRC so RAM
chips latch the select, matching the historical chips' address-latch enable
behavior.

### 5.3 Accumulator group

| Mnemonic | Encoding | Semantics |
|----------|----------|-----------|
| CLB | 1111 0000 | ACC ← 0, CY ← 0 |
| CLC | 1111 0001 | CY ← 0 |
| IAC | 1111 0010 | {CY, ACC} ← ACC + 1 |
| CMC | 1111 0011 | CY ← ~CY |
| CMA | 1111 0100 | ACC ← ~ACC |
| RAL | 1111 0101 | {CY, ACC} ← {ACC, CY} (rotate left through carry) |
| RAR | 1111 0110 | {CY, ACC} ← {ACC[0], CY, ACC[3:1]} (rotate right through carry) |
| TCC | 1111 0111 | ACC ← {3'b0, CY}, CY ← 0 |
| DAC | 1111 1000 | {CY, ACC} ← ACC + 15 (i.e., ACC - 1) |
| TCS | 1111 1001 | ACC ← CY ? 9 : 10 (2's-complement tens digit, 4-bit); CY ← 0 |
| STC | 1111 1010 | CY ← 1 |
| DAA | 1111 1011 | If CY = 1 or ACC > 9 then {CY', ACC} ← ACC + 6 (CY' is the carry of that add); otherwise CY unchanged |
| KBP | 1111 1100 | ACC ← one-hot-to-binary of old ACC: 0→0, 1→1, 2→2, 4→3, 8→4, any other value (0 or >1 bits set)→15 |
| DCL | 1111 1101 | CMD ← ACC[2:0] |

Undefined accumulator-group combinations 1111 1110 and 1111 1111 execute as
NOPs (5.6); they are the only encodings without a defined function.

### 5.4 JCN conditions

The condition code C4C3C2C1 (bits of OPA) selects:

| Code | Condition contribution |
|------|------------------------|
| C1 (bit 3) | Invert: jump if the selected-condition OR is false instead of true |
| C2 (bit 2) | ACC = 0 |
| C3 (bit 1) | CY = 1 |
| C4 (bit 0) | TEST pin low (`test_i` = 0) |

`jump = ~C1·((ACC=0)·C2 + (CY=1)·C3 + ~test_i·C4) + C1·~((ACC=0)·C2 + (CY=1)·C3 + ~test_i·C4)`.

Selected conditions OR together; with no conditions selected the raw jump
condition is false, so `0001 0000` never jumps and `0001 1000` jumps
unconditionally. The target is `{PC[11:8], A2A1}` where PC[11:8] is the
program counter's page after both fetches of the two-word instruction.

### 5.5 Stack behavior

JMS rotates SP (SP ← SP + 1, a circular 4-register stack) and writes the
return address — the PC value after both fetches, i.e., first word + 2 — into
the new stack[SP], then loads PC = {A3, A2, A1}. BBL rotates SP back
(SP ← SP - 1) and resumes from stack[SP]. A fourth nested JMS overwrites the
deepest return address (documented overflow behavior); BBL from a shallower
depth returns correctly regardless.

### 5.6 Undefined opcodes

The two encodings without a function in the tables above — 1111 1110 and
1111 1111 — execute as NOPs: control flow proceeds to the next word. This NOP
behavior is a documented reconstruction choice, consistent with the real
instruction decoder, which simply activates no micro-operation for undefined
combinations.

### 5.7 Subtract carry convention

SUB and SBM both compute `{CY, ACC} ← ACC + ~operand + ~CY` with the add's
carry-out becoming the new CY: CY = 1 means no borrow, and an incoming CY = 0
contributes the pending borrow. This follows the MCS-4 manual's SBM equation,
`(ACC) + ~(M) + ~(CY)`, and applies the same sense to SUB, matching the
shared subtract datapath of the real part and hardware-validated
implementations that run the original Busicom ROMs. (The manual's printed SUB
equation omits the inversion; the discrepancy is noted here rather than
silently resolved either way.) Example: ACC = 5, R = 3, CY = 0 gives ACC = 2,
CY = 1 — five minus three with no borrow out.

## 6. Bus Protocol and Timing

### 6.1 Instruction cycle

Every instruction cycle is 8 clocks. On each rising edge of `clk` the phase
advances; phase 0 is A1.

1. **A1**: `sync` = 1 for this clock period. CPU drives `data_o` =
   PC[3:0]; at the edge ending A1, PC ← PC + 1 (mod 4096).
2. **A2**: CPU drives `data_o` = PC[7:4] (pre-increment value captured at
   A1).
3. **A3**: CPU drives `data_o` = PC[11:8]. `cm_rom` = 1 throughout A1-A3 so
   ROMs latch the 12-bit address.
4. **M1**: selected ROM drives the word's high nibble; CPU latches OPR at the
   edge ending M1.
5. **M2**: selected ROM drives the word's low nibble; CPU latches OPA at the
   edge ending M2.
6. **X1-X3**: execution. Bus activity only for SRC and OPR = 1110
   instructions (6.3). All architectural updates commit at the edge ending
   the instruction's final X3.

The PC increment at A1 of every cycle is what makes the historical quirks
fall out naturally: a two-word instruction starting at word 254 of a page
fetches its second word from word 255, and by the time the branch target's
page is taken from PC[11:8] the counter has rolled into the next page —
exactly the documented "branch targets are within the same page, except when
the instruction straddles the page boundary" behavior. FIN/JIN inherit the
same post-increment page for their fetches.

### 6.2 Two-cycle instructions

JCN, FIM, JUN, JMS, ISZ (two-word) and FIN (one word) run a second
instruction cycle. The second cycle fetches the second word at PC (which A1
of cycle 1 has already incremented onto it). Special second-cycle bus
behavior:

- **FIN**: during A1-A3 of the second cycle the CPU drives {R1, R0, PC[11:8]}
  (low to high) instead of PC, fetching from {PC[11:8], R0, R1}.
- **JUN/JMS/JCN/ISZ**: the second cycle's A1-A3 drive the PC as usual (the
  branch target is formed from A3 latched in cycle 1 plus the second word),
  and PC is updated with the branch target at the end of X3.
- **FIM**: the second word is data, loaded into the designated pair.

### 6.3 X2/X3 I/O operations

| Operation class | X2 | X3 |
|-----------------|----|----|
| SRC | drive pair high nibble (RRR0) | drive pair low nibble (RRR1); latch SRC pointer at end of X3 |
| Write ops (WRM, WMP, WR0-3, WRR) | drive ACC | drive ACC; memory latches at end of X3 |
| Read ops (RDM, RD0-3, RDR, ADM, SBM) | (memory drives) | memory drives ACC source; CPU samples at edge ending X3 |

`cm_ram` = DCL decode of CMD during X2-X3 of SRC and all OPR = 1110
instructions except WRR/RDR (which use the ROM port) and WPM/reserved (no
activity). `cm_rom` is asserted only during A1-A3 (all cycles), as on the
historical part.

### 6.4 Reset

`rst_n` low (synchronous) clears ACC, CY, SP, the four stack registers, the
sixteen index registers, the SRC pointer, and CMD (bank 0 active). The
historical RESET pin likewise clears all registers and flip-flops — held long
enough (at least eight instruction cycles) it also sweeps the dynamic
index-register array clear. On release the CPU starts fetching from PC = 0.
The phase counter resets to A1 and `sync` asserts on the first cycle after
release.

## 7. Error Handling

There are no error or status outputs. Undefined opcodes are NOPs (5.6),
stack overflow is silent circular overwrite (5.5), and page-boundary
straddling follows 6.2. All such conditions are architecturally defined.

## 8. Power Considerations

Not modeled. The historical part is PMOS with a 10.8 µs instruction cycle at
the 740 kHz maximum clock; this core has no clock gating or power domains.

## 9. Constraints

- Synthesis: pure RTL, single clock, synchronous reset; no latches, no
  memories inferred (stack is a 4×12 register array).
- Performance: one architectural instruction per 8 or 16 `clk` cycles.
- Area: single small module; exact Yosys cell count reported in
  `report/final_report.md`.

## 10. Sources

- MCS-4 Micro Computer Set user manual (scanned original, including the
  instruction repertoire tables, JCN condition-code note, DCL/SRC command
  line operation, stack description, and the WPM description for
  4008/4009 systems): <http://codeabbey.github.io/heavy-data-1/msc4-manual.pdf>;
  instruction repertoire and timing also transcribed at the e4004 project,
  <http://e4004.szyc.org/iset.html>.
- Launch date, architecture summary, register diagram, and instruction
  count: Intel 4004 historical summary,
  <https://en.wikipedia.org/wiki/Intel_4004>.
- Opcode matrix and cycle counts (including the FIN 1-word/2-cycle
  exception): pastraiser Intel 4004 opcode table,
  <https://pastraiser.com/cpu/i4004/i4004_opcodes.html>.
- Encoding cross-check including STC and the RAM/port group: Pyntel4004
  opcode list, <https://pyntel4004.readthedocs.io/en/latest/intro/opcodes.html>.
- Cross-validation of instruction semantics (notably the subtract carry
  sense, JCN condition bit order, and WPM bus behavior) against a
  hardware-validated implementation that executes the original Busicom
  ROMs: MAME MCS-40 CPU core,
  <https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp>.

Source content is summarized and rephrased for licensing compliance; no
source text is reproduced verbatim beyond signal names and mnemonics.

## 11. Out of Scope

- Electrical behavior: PMOS voltage levels, φ1/φ2 non-overlap timing, input/
  output capacitance, drive strength, the 16-pin package, and power
  sequencing.
- Asynchronous RESET behavior: the historical part resets asynchronously at
  any phase; this core defines reset sampling on `clk`.
- Two-phase clock generation and the 4003 shift register; `clk` models the
  clock-period rate directly.
- WPM physical context: this core drives the ACC half-byte on the bus with
  `cm_rom` asserted during X2-X3; the 4008/4009 chip-select and
  first/last half-byte lane mechanics of real program-RAM systems are
  memory-side behavior.
- Interrupts and bank switching: introduced by the 4040, not the 4004.
- Cycle-exact CPU-internal micro-operation ordering; only the externally
  visible bus protocol and architectural state are specified.
