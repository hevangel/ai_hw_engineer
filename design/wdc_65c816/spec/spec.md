# Specification: WDC W65C816S CPU core

## 1. Overview

A 16-bit microprocessor with a 6502-compatible emulation mode. Registers:
accumulator C (A/B halves), X, Y (8 or 16 bits by the M and X flags), stack
pointer S, direct page D, program bank PBR, data bank DBR, program counter
PC and status P (NVMXDIZC, with E as the hidden emulation bit swapped by
XCE). All 256 opcodes are defined.

The core is used inside the [Ricoh 5A22](../../ricoh_5a22/), which supplies
the clock enable that stretches each bus cycle to 6, 8 or 12 master clocks.

## 2. Interfaces

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Clock and synchronous active-low reset (RESB) |
| `ce` | in | 1 | Last clock of the current bus cycle; state advances only here |
| `irq_n`, `nmi_n` | in | 1 | IRQB (level) and NMIB (falling edge) |
| `addr_o` | out | 24 | Bank and address of the current cycle |
| `data_i` | in | 8 | Read data, sampled at `ce` |
| `data_o` | out | 8 | Write data |
| `we_o` | out | 1 | Write cycle (inverse of RWB) |
| `vda_o`, `vpa_o` | out | 1 | Valid data / program address; both low = internal cycle |
| `vpb_o` | out | 1 | Vector pull (active high) |
| `ml_o` | out | 1 | Memory lock during read-modify-write (active high) |
| `e_o`, `m_o`, `x_o` | out | 1 | E, M and X pins |
| `fetch_o` | out | 1 | Opcode fetch (VDA and VPA both high) |
| `waiting_o`, `stopped_o` | out | 1 | WAI asleep, STP stopped |
| `pc_o` … `pbr_o` | out | | Register observation |

The bus request of a cycle is combinational from the registered state, so a
bus controller can decode the address before deciding the cycle length.

## 3. Behaviour

- Reset: a five-cycle sequence (three dummy stack reads, then the vector
  pull from `$00FFFC`), E=1, M=X=1, D=0, DBR=PBR=0, S high byte `$01`,
  I=1, D flag clear.
- Interrupts are sampled at the end of each instruction; NMI is latched on
  its falling edge. Native mode pushes PBR; emulation mode pushes P with
  B=0 and uses the emulation vectors. BRK/COP use their own vectors.
- Decimal ADC/SBC operate one nibble at a time with the documented
  65C816 flag results (V from the binary-coded intermediate).
- Emulation-mode quirks reproduced: stack page wrap to `$01xx` for the
  6502 instructions, direct-page wrap when DL=0, and the extra write of
  the unmodified value in read-modify-write instructions.
- MVN/MVP move one byte per seven cycles and re-fetch the opcode until C
  becomes `$FFFF`. WAI waits for any interrupt line; STP stops until reset.

## 4. Sources

- [WDC W65C816S datasheet](https://www.westerndesigncenter.com/wdc/documentation/w65c816s.pdf):
  instruction set, addressing modes, cycle tables (table 5-7), pin functions.
- [SingleStepTests 65816](https://github.com/SingleStepTests/65816) at
  revision `307c63f5`: 10,000 random cases per opcode and mode (100 for
  MVN/MVP), each with every bus cycle's address, data and pin state,
  generated from a validated reference implementation. Used as the
  independent oracle; expected values are never edited.

## 5. Assumption ledger

| Assumption | Evidence | Status |
|---|---|---|
| In emulation mode the read-modify-write extra cycle writes the old value; in native mode it is an internal cycle | SingleStepTests records | Implemented; matches all cases |
| RTI applies the pulled P at the end of the instruction (M/X pins change late) | SingleStepTests records | Implemented |
| The WDM operand cycle is an internal cycle with no VPA | SingleStepTests records | Implemented |
| MVN/MVP update X, Y and C at the end of each 7-cycle iteration; the internal cycles show the old Y | SingleStepTests records | Implemented |
| JSR (a,x) in emulation mode leaves S high byte `$01` at the end | SingleStepTests records | Implemented |
| WAI/STP cycles while halted have no meaningful address | The records give a null address | Harness expects the waiting/stopped state instead |
| ABORTB, RDY as an input, BE and the MX demultiplexed bank byte on D7–D0 are not modelled | Not used by the 5A22 | Out of scope |
