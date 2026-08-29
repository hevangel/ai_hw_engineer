# Specification: Intel 4002

## 1. Overview

The Intel 4002 is the RAM chip of the MCS-4 four-chip micro computer set
(4001 ROM, 4002 RAM, 4003 shift register, 4004 CPU), announced by Intel on
November 15, 1971 and originally developed for the Busicom 141-PF calculator.
One 4002 stores 320 bits arranged as four registers of twenty 4-bit
characters each — sixteen main-memory characters and four status characters
per register — and additionally provides a 4-bit latched output port for
driving peripheral devices. Up to four 4002s share one CM-RAM command line
(distinguished by a 2-bit chip number sent with every SRC pointer), and the
4004 can drive up to four CM-RAM lines (banks), giving a maximum of 5120 RAM
bits and 16 output ports per MCS-4 system.

This specification defines the behavioral contract implemented by
`src/intel_4002.sv`: a synchronous, synthesizable functional reconstruction
of the chip's programming model and 8-phase bus protocol, not an electrical,
timing-, or transistor-level model of the PMOS part. The historical chip is
dynamic RAM with an internal refresh counter, runs on two non-overlapping
clock phases, and resets asynchronously; this core models the array as static
storage, samples everything on a single `clk`, and adds a synchronous
active-low `rst_n`. Section 11 lists what is deliberately out of scope and
Section 9 lists every reconstruction decision where the sources leave room
for interpretation.

The bus-side protocol of this core is written to interoperate directly with
the repository's verified `intel_4004` core (`design/intel_4004/`, branch
`design/add-intel-4004`): the two chips' phase counters, SRC nibble
placement, command-line gating, and write/read commit edges match that
implementation exactly, so a future full-system integration can connect the
4002 to the 4004 without glue logic.

## 2. Features

- 320 bits of storage: 4 registers x 16 main-memory characters x 4 bits
  (256 bits) plus 4 registers x 4 status characters x 4 bits (64 bits).
- 4-bit latched output port driven by the WMP instruction, holding its value
  until the next WMP or reset.
- Full MCS-4 RAM command set decode: WRM, WMP, WR0-WR3 (writes); RDM, ADM,
  SBM, RD0-RD3 (reads). The CPU-side arithmetic of ADM/SBM lives in the 4004;
  the 4002 only supplies the memory nibble.
- The historical 8-period instruction cycle (A1 A2 A3 M1 M2 X1 X2 X3)
  tracked from the CPU's `sync` pulse; command decode by listening to the
  instruction word on the shared bus at M1/M2.
- SRC pointer latching exactly as the MCS-4 manual defines: chip number and
  register number from the X2 nibble, character number from the X3 nibble.
- Chip selection per the historical 4002-1 / 4002-2 metal options and the P0
  strap pin (Section 6), so both variants can be modeled.
- CM-RAM bank-line input: a chip responds only while its bank line is
  asserted, enabling the 4004's DCL-selected multi-bank operation.

## 3. Interfaces

### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | Master clock; one clock per historical clock period |
| `rst_n` | input | 1 | Active-low synchronous reset (reconstruction addition; see 7) |
| `data_i` | input | 4 | Bus nibble driven into the chip (input half of the 4-bit bus) |
| `data_o` | output | 4 | Bus nibble driven by the chip during RAM reads |
| `data_oe` | output | 1 | 1 when the chip drives the bus (external integration gates `data_o` onto the shared wire) |
| `sync` | input | 1 | Historical SYNC from the CPU: 1 during A1, the first clock period of every instruction cycle |
| `cm_ram_i` | input | 1 | This chip's CM-RAM bank command line (one of the CPU's four decoded lines, wired one chip-group per line) |
| `po_i` | input | 1 | Historical P0 chip-number strap pin (0 = GND, 1 = Vdd); see Section 6 |
| `io_o` | output | 4 | 4-bit latched output port (historical I/O0-I/O3 pins) |

The historical D0-D3 bidirectional bus is represented as separate input
(`data_i`), output (`data_o`), and output-enable (`data_oe`) signals, matching
the convention used across this repository, including the verified
`intel_4004` core.

### 3.2 Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Variant1` | `1'b1` | 1 models a 4002-1 (responds to chip numbers 0 and 1); 0 models a 4002-2 (chip numbers 2 and 3). See Section 6. |

## 4. The Instruction Cycle, Phase by Phase

The 4004 defines an instruction cycle of eight clock periods. This core
maintains a 3-bit phase counter synchronized by `sync`: `sync` sampled high
forces the counter to restart, so phase 0 coincides with the A1 period of
every cycle, exactly as on the historical part. The phase counter advances
on every rising `clk` edge; `sync` is sampled at the edge that ends A1, so
the edge ending A1 moves the counter to phase 1 (A2).

| Phase (encoding) | Period | What this chip does |
|------------------|--------|---------------------|
| 0 | A1 | `sync` input is high. No bus activity. |
| 1 | A2 | Idle (the CPU multiplexes the program address; ROMs respond). |
| 2 | A3 | Idle. (Historically the CM-RAM lines pulse at A3 to keep the dynamic array's power-share timing honest; the reconstruction needs no refresh and takes no action.) |
| 3 | M1 | The CPU's instruction word high nibble (OPR) is on the bus; every chip listens. This chip latches `cmd_opr <= data_i`. |
| 4 | M2 | The instruction word low nibble (OPA) is on the bus; this chip latches `cmd_opa <= data_i`. Together {cmd_opr, cmd_opa} is the instruction this chip will consider executing in X2/X3 of the same cycle. |
| 5 | X1 | Idle. |
| 6 | X2 | SRC: latch the select-code high nibble (chip number + register number) if this chip's bank line is active. RAM read commands: drive the selected nibble onto the bus. |
| 7 | X3 | SRC: latch the select-code low nibble (character number). Write commands (WRM/WMP/WR0-WR3): capture `data_i` into the selected location at the edge ending this phase. Read commands: keep driving the selected nibble; the CPU samples it at the edge ending X3. |

## 5. Functional Description

### 5.1 Addressing: the SRC select code

The 4004's SRC instruction sends the contents of a designated index-register
pair during X2 (high nibble) and X3 (low nibble) of its one-cycle
instruction, with the DCL-selected CM-RAM line asserted. The MCS-4 manual
defines the interpretation:

| Phase | Bus bits | Meaning |
|-------|----------|---------|
| X2 | D3 D2 | Chip number (0-3) |
| X2 | D1 D0 | Register number (0-3) |
| X3 | D3..D0 | Main-memory character number (0-15) |

A chip whose CM-RAM line is active loads both nibbles into its 8-bit address
register — every chip on the active line does so, regardless of its own chip
number. Whether the chip *responds* to a later RAM command is decided
separately by the chip-selection logic (Section 6): response requires the
active bank line AND an address-register chip number matching the chip's
own number.

The address register holds one main-memory position: register `addr[5:4]`,
character `addr[3:0]`, plus the chip number `addr[7:6]` used only for
selection. Status characters are not addressed by the character field: the
WR0-WR3/RD0-RD3 opcode itself selects which of the four status characters
of the addressed register is meant.

### 5.2 Command decode

All chips on the bus hear every instruction at M1/M2. This chip considers
an instruction its own when `cmd_opr` = 1110 (the I/O and RAM group); the
OPA then selects the operation:

| Mnemonic | OPA | Class | 4002 action (at X2/X3 of the same instruction cycle) |
|----------|-----|-------|-------------------------------------------------------|
| WRM | 0000 | write | main memory character at {register, character} ← bus at end of X3 |
| WMP | 0001 | write | output port latch ← bus at end of X3 |
| WRR | 0010 | — | not a 4002 operation (ROM I/O port write); ignored |
| WPM | 0011 | — | not a 4002 operation (program-memory write); ignored |
| WR0 | 0100 | write | status character 0 of the selected register ← bus at end of X3 |
| WR1 | 0101 | write | status character 1 ← bus at end of X3 |
| WR2 | 0110 | write | status character 2 ← bus at end of X3 |
| WR3 | 0111 | write | status character 3 ← bus at end of X3 |
| SBM | 1000 | read | drive main-memory nibble during X2/X3 (CPU subtracts it) |
| RDM | 1001 | read | drive main-memory nibble during X2/X3 |
| RDR | 1010 | — | not a 4002 operation (ROM I/O port read); ignored |
| ADM | 1011 | read | drive main-memory nibble during X2/X3 (CPU adds it) |
| RD0 | 1100 | read | drive status character 0 during X2/X3 |
| RD1 | 1101 | read | drive status character 1 during X2/X3 |
| RD2 | 1110 | read | drive status character 2 during X2/X3 |
| RD3 | 1111 | read | drive status character 3 during X2/X3 |

Writes and reads are distinguished exactly as the manual states: OPA bit 3
clears for the I/O-write group (0000-0111) and sets for the I/O-read group
(1000-1111), with the three ROM-side exceptions WRR/WPM/RDR ignored by this
chip.

ADM and SBM deserve emphasis: the 4002 supplies only the memory nibble on
the bus. The accumulate-with-carry / subtract-with-borrow arithmetic happens
in the CPU, which samples the nibble at the edge ending X3.

### 5.3 Read and write bus timing

- **Write commands** (WRM, WMP, WR0-WR3): the CPU drives the accumulator on
  the bus during X2 and X3 (stable across both periods). The chip captures
  `data_i` into the selected location at the edge ending X3.
- **Read commands** (RDM, ADM, SBM, RD0-RD3): the chip drives the selected
  nibble onto the bus with `data_oe` high during X2 and X3. The verified
  repository 4004 samples the bus only at the edge ending X3; driving from
  X2 also matches the phase-2 data placement reported by the MAME MCS-40
  core, so both references are satisfied.
- **SRC**: the chip never drives the bus during a SRC cycle; it only loads
  its address register (while its bank line is active).

### 5.4 Output port

WMP writes the bus value into the 4-bit output latch; the value then holds
on the `io_o` pins until the next WMP or a reset. Like the RAM array, the
port is only updated by an instruction explicitly addressed to this chip
(active bank line + matching chip number); writing the port of one 4002
never disturbs another chip's port.

### 5.5 Multi-chip and multi-bank systems

A realistic system wires each CM-RAM output of the CPU to one group of up to
four 4002s (chip numbers 0-3). This core models exactly one such participant:

- `cm_ram_i` is that chip's bank line. When low, the chip ignores SRC
  address loads and never responds to commands.
- The DCL instruction in the CPU decodes its 3-bit command register into the
  four CM-RAM lines (line 0 selected when the register is zero; line k,
  k=1..3, follows register bit k-1). This chip has no DCL state of its own;
  bank switching is visible to it purely as `cm_ram_i` activity.
- Chips of different banks keep independent address registers. Switching
  banks without a fresh SRC makes the newly selected bank respond per its
  stale address register — historically accurate and reproduced here.

## 6. Chip Selection: 4002-1 vs 4002-2 and the P0 pin

The manual's chip-number assignment, reworded as a table:

| Chip number (D3 D2 at X2) | Metal option | P0 pin |
|---------------------------|--------------|--------|
| 00 | 4002-1 | GND (`po_i` = 0) |
| 01 | 4002-1 | Vdd (`po_i` = 1) |
| 10 | 4002-2 | GND (`po_i` = 0) |
| 11 | 4002-2 | Vdd (`po_i` = 1) |

So the two variants differ only in the decode of the chip-number MSB: a
4002-1 answers chip numbers 0 and 1, a 4002-2 answers chip numbers 2 and 3.
The P0 strap pin selects which of the two numbers within the variant this
individual chip owns. The reconstruction exposes both knobs: parameter
`Variant1` (metal option) and input `po_i` (strap). The chip responds to a
RAM command exactly when `cm_ram_i` is high and
`addr[7:6] == {Variant1 ? 1'b0 : 1'b1, po_i}`.

## 7. Reset

`rst_n` low (synchronous) clears the output port latch, the address
register, the M1/M2 command latches, the phase counter, and the entire RAM
array (all 80 nibbles). The historical RESET pin also clears all output and
control flip-flops and sweeps the dynamic array clear, but only when held
for at least 32 instruction cycles so the internal refresh counter visits
every cell; the reconstruction, modeling static storage, clears everything
after the single reset edge regardless of pulse width. During reset
`data_oe` is forced low (the historical chip floats its bus output buffers
during RESET). After release the chip waits for the next `sync` and is fully
operational immediately.

## 8. Constraints

- Synthesis: pure RTL, single clock, synchronous reset; no latches; the
  array is 64 + 16 4-bit registers (small enough to synthesize as
  flip-flops; no block RAM inference required).
- Performance: one bus operation per 8-`clk` instruction cycle.
- Area: exact Yosys cell count recorded in `report/final_report.md`.

## 9. Interpretations and Reconstruction Decisions

1. **Command decode by bus listening at M1/M2.** The manual states the CPU
   activates the selected CM-RAM line at M2 "in time for the 4002s to
   receive the OPA", i.e. the historical chips decode the operation from the
   instruction word broadcast to all chips during M1/M2. The repository's
   verified 4004 asserts `cm_ram` only during X2/X3 (not M2), so this chip
   latches the OPR/OPA at M1/M2 unconditionally and applies the
   bank-line/chip-number gating only to execution in X2/X3. This preserves
   the historical decode mechanism while remaining drop-in compatible with
   the repository CPU.
2. **Write commit at the edge ending X3.** The manual pins only WMP data
   ("data present on the data bus during X2" sets the output flip-flops).
   The repository 4004's system model commits all RAM-side writes (main,
   status, output port) at the end of X3, and the CPU holds the accumulator
   stable across X2 and X3, so both choices are indistinguishable in a real
   system; this core follows the repository model (end of X3) for uniformity.
3. **Read drive from X2.** The manual's per-instruction action table is
   unreadable in the available scan, and secondary references disagree (MAME
   presents read data at X2; the repository 4004 samples at the end of X3).
   Driving during both X2 and X3 satisfies both references; the conflict is
   documented here rather than silently resolved.
4. **Address-register loading is bank-gated but not chip-number-gated.**
   Every 4002 on the active CM-RAM line loads the SRC select code; only the
   chip-number match (plus the bank line) gates the response. This follows
   the manual's separate treatment of address loading and "chip selection
   logic" and is what makes multi-chip banks work.
5. **Static array, full-clear reset.** The dynamic cell array and its
   refresh counter are out of scope (Section 11); reset clears the whole
   array in one clock instead of sweeping it over 32 instruction cycles.
6. **Synchronous reset.** The historical RESET is asynchronous; this core
   samples `rst_n` on `clk`, matching the repository convention.

## 10. Sources

- MCS-4 Micro Computer Set Users Manual (Feb 1973 scan, bitsavers):
  <https://archive.org/details/bitsavers_intelMCS4M_18342130> — 4002 chapter
  (320-bit organization, SRC select-code table, chip-number/variant table,
  CM-RAM activation timing, WMP output-port behavior, RESET behavior), the
  I/O and RAM instruction descriptions, and the DCL instruction description.
- MCS-4 Data Sheet, November 1971 (deramp.com scan):
  <https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf> —
  the 4002's two metal options (4002-1 / 4002-2) and the four-CM-RAM-line
  bank architecture.
- MAME MCS-40 CPU core (behavioral cross-reference for CPU-side phase
  timing, the RAM address = {command register, SRC pointer} composition, and
  the DCL command-line decode table):
  <https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp>.
- Intel 4004 historical summary (announcement date November 15, 1971, family
  roles of the MCS-4 chips): <https://en.wikipedia.org/wiki/Intel_4004>.
- Repository-internal contract: `design/intel_4004/spec/spec.md` and the
  4004 testbench's RAM-side model (branch `design/add-intel-4004`), which fix
  the phase-level bus protocol this chip must honor.

Source content is summarized and rephrased for licensing compliance; no
source text is reproduced verbatim beyond device, signal, and mnemonic names.

## 11. Out of Scope

- Electrical behavior: PMOS levels, phi1/phi2 non-overlap clocks, bus
  precharge, drive strength, package pinout, and power sequencing.
- The dynamic memory cell array and its refresh counter/refresh amplifiers;
  storage is modeled as static.
- Asynchronous RESET sampling and the refresh-sweep reset latency (see 7,
  9.5).
- Power-down / standby modes described in later 4002 datasheet revisions.
- The 4002's role in 4008/4009-based systems (WPM contexts), which is a CPU
  and program-memory concern.
- Analog characteristics of the output port (rise times, capacitive drive).
