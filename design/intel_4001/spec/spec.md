# Specification: Intel 4001

## 1. Overview

The Intel 4001 is the program-memory and input/output chip of the MCS-4
four-chip microcomputer set (4004 CPU, 4001 ROM + I/O, 4002 RAM + output
port, 4003 shift register) that Intel announced to the general market through
an advertisement in the November 15, 1971 issue of *Electronic News*. The
family was originally developed for the Busicom 141-PF desktop calculator,
with engineering samples already delivered to Busicom earlier in 1971, before
the public announcement.

Each 4001 combines two distinct functions on one 16-pin PMOS chip:

1. **ROM**: 2048 bits of metal-mask-programmable program storage, organized
   as 256 words of 8 bits (one full program-memory page of the 4K-word MCS-4
   address space). Up to sixteen 4001s hang on the shared 4-bit bus and one
   CM-ROM command line; each chip carries a 4-bit chip number that is a metal
   mask option, selected by comparing the chip-number nibble the CPU sends
   during the A3 clock period.
2. **I/O port**: one 4-bit input/output port. The CPU writes the port with
   the WRR instruction and reads it back with RDR; the port is selected for
   these operations by the chip-number nibble the CPU sends at X2 of the
   preceding SRC instruction. Each of the four I/O pins is individually
   mask-programmable as an input or an output (with optional inversion and
   pull-up choices that are electrical, not logical, and out of scope here).

This specification defines the behavioral contract implemented by
`src/intel_4001.sv`. Like the companion 4004 CPU reconstruction, it is a
synchronous, synthesizable functional model, not an electrical or
transistor-level model: the historical two-phase non-overlapping clock φ1/φ2
is replaced by a single `clk` (one rising edge per historical clock period),
the asynchronous RESET and CL pins become synchronous active-low `rst_n` and
`clr_n`, and the bidirectional D0-D3 bus is decomposed into `data_i`,
`data_o`, and `data_oe` following the repository convention. Section 11
lists what is deliberately out of scope.

## 2. Features

- 256 x 8 mask-programmable ROM, one 256-word program-memory page per chip,
  addressed through the multiplexed A1/A2/A3 bus periods with CM-ROM active.
- 4-bit chip number as a synthesis parameter (`CHIP_NO`), reproducing the
  metal mask option; up to 16 chips share one bus and CM-ROM line.
- 4-bit I/O port with per-pin direction mask option (`IO_DIR` parameter);
  WRR latches a bus nibble into the port, RDR drives the port pins onto the
  bus. Port selection via the SRC chip-number nibble latched at X2.
- Faithful 8-period instruction-cycle behavior: address latching at
  A1 (word low nibble), A2 (word high nibble), A3 (chip number, qualified by
  `cm_rom`), data driving at M1 (word high nibble) and M2 (word low nibble),
  port operations at X2/X3.
- Self-synchronizing phase counter locked to the CPU's `sync` pulse.
- Separate reset semantics matching the historical pins: `rst_n` (RESET)
  clears the sequencer and selection flip-flops and inhibits bus output,
  while `clr_n` (CL) clears only the I/O output latch. ROM contents are
  mask data and unaffected by either.
- On-chip opcode snoop of fetched OPR/OPA so the chip participates in SRC,
  WRR, and RDR without requiring extra command-line qualifications beyond
  what either the historical 4004 or the reconstructed `intel_4004` drives.

## 3. Interfaces

### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | Master clock; one rising edge per historical clock period (φ period) |
| `rst_n` | input | 1 | Active-low synchronous reset, models the historical RESET pin (see 6.2) |
| `clr_n` | input | 1 | Active-low synchronous clear of the I/O output latch only; models the historical CL pin |
| `data_i` | input | 4 | Bus nibble driven by the CPU (input half of the D0-D3 bus) |
| `data_o` | output | 4 | Bus nibble driven by this chip (output half of the D0-D3 bus) |
| `data_oe` | output | 1 | 1 when this chip drives the bus (external integration may gate `data_o`) |
| `sync` | input | 1 | Historical SYNC from the CPU: 1 during A1 of every instruction cycle |
| `cm_rom` | input | 1 | Historical CM-ROM command line from the CPU |
| `port_i` | input | 4 | Values present on the four external I/O pins (input pins feed RDR) |
| `port_o` | output | 4 | Output values for the four external I/O pins (from the port latch) |
| `port_oe` | output | 4 | Per-pin output enable = `IO_DIR` mask (1 = output pin) |

The historical 16-pin DIP carries Vdd/Vss, φ1/φ2, SYNC, CM-ROM, RESET, CL,
the shared D0-D3 data bus, and the four I/O lines. In a pin-accurate
integration `data_o` would be tri-stated by `data_oe` onto a shared wire and
`port_o` gated per-pin by `port_oe`.

### 3.2 Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CHIP_NO` | 4'h0 | Metal-option chip number 0-15 compared against the A3 nibble and the SRC X2 nibble |
| `IO_DIR` | 4'b1111 | Per-pin I/O direction mask option: 1 = output pin, 0 = input pin |
| `ROM_FILE` | `src/rom_4001_default.hex` | Hex file holding the mask-programmed ROM contents, loaded with `$readmemh`: one 8-bit word per line, 256 lines in address order; word at address *a* is line *a*+1. The path resolves against the simulator's working directory |

The default ROM pattern is a fixed, address-distinguishable function
chosen for verification (`src/rom_4001_default.hex`); real chips are
ordered with an arbitrary customer truth table, supplied as their own hex
file. In formal mode the contents vector is replaced by a free constant
(`anyconst`) so proofs cover every possible mask and no file is read.

## 4. The MCS-4 Instruction Cycle

One instruction cycle is eight clock periods named A1, A2, A3, M1, M2, X1,
X2, X3. The CPU pulses `sync` during A1 of every cycle (including the second
cycle of two-cycle instructions) and asserts `cm_rom` during A1-A3 of every
cycle and during X2-X3 of the ROM-port I/O instructions WRR, WPM, and RDR.
This chip maintains its own 3-bit phase counter that locks to `sync`: a
period in which `sync` is 1 is treated as A1 and the counter advances one
period per `clk` edge thereafter, staying aligned with the CPU.

### 4.1 Phase-by-phase behavior

| Phase | Inputs qualified | Chip action |
|-------|------------------|-------------|
| A1 | `sync`=1, `cm_rom`=1 | Latch `data_i` as word address bits [3:0] (low nibble). Internal: phase counter re-locks on `sync`. |
| A2 | `cm_rom`=1 | Latch `data_i` as word address bits [7:4] (high nibble). |
| A3 | `cm_rom`=1 | Latch `data_i` as the chip-number nibble; `fetch_selected` is set if it equals `CHIP_NO`. |
| M1 | — | If `fetch_selected`: drive `data_o` = ROM word [7:4] (OPR), `data_oe`=1. All chips snoop `data_i` as the fetched OPR. |
| M2 | — | If `fetch_selected`: drive `data_o` = ROM word [3:0] (OPA), `data_oe`=1. All chips snoop `data_i` as the fetched OPA. |
| X1 | — | No bus activity. |
| X2 | — | If snooped word was SRC (OPR = 0010, OPA bit 0 = 1): latch `data_i` as the ROM-port select nibble (`io_selected` = select = `CHIP_NO`). If snooped word was RDR and `io_selected`: drive `data_o` = port read value (7.3), `data_oe`=1. |
| X3 | — | Same RDR drive as X2. If snooped word was WRR (OPR = 1110, OPA = 0010) and `io_selected`: latch `data_i` into the I/O output port latch on the edge ending X3. |

An 8-bit ROM word is produced by concatenation: the chip latches the low
nibble first (A1), the high nibble second (A2), matching the CPU's
low-nibble-first address transmission (CPU drives `addr[3:0]` at A1,
`addr[7:4]` at A2, chip number at A3). This ordering is confirmed both by
the MCS-4 Users Manual, which describes the 4001 as receiving an 8-bit
address during the A1 and A2 periods and the chip number together with
CM-ROM during A3, and by the verified `intel_4004` reconstruction and the
MAME MCS-40 core.

### 4.2 Reset alignment

`rst_n` resets the phase counter to A1. Because the companion CPU
reconstruction also restarts at A1, chip and CPU stay phase-locked from the
first cycle after reset release; the `sync` re-lock keeps them aligned even
if reset release timing differs between the two chips.

## 5. Chip Operations

### 5.1 Program fetch (ROM mode)

Per the manual, ROM-mode activity occupies A1 through M2 only: the selected
chip (A3 chip number = `CHIP_NO`, CM-ROM present) drives the word's high
nibble at M1 and low nibble at M2, and releases the bus afterwards. A
non-selected chip never drives during M1/M2. Every instruction cycle is a
fetch cycle, including the second cycles of two-word instructions and the
I/O instructions themselves, so this behavior is unconditional (given
`cm_rom` qualification) and identical in every cycle.

### 5.2 SRC (send register-pair content as select code)

The CPU sends an 8-bit select code at X2 (high nibble) and X3 (low nibble).
The manual specifies that the 4001 interprets the X2 nibble — sent with
CM-ROM active — as the chip number of the unit that should later perform an
I/O operation, and ignores X3 data. This chip latches the X2 nibble into the
I/O select register and compares it against `CHIP_NO` to form `io_selected`.
X3 data is not captured. See 10.2 for the one deliberate deviation: the
select latch is qualified by the snooped SRC opcode rather than by `cm_rom`.

### 5.3 WRR (write ROM port), encoding 1110 0010

The CPU drives the accumulator nibble on the bus during X2 and X3. The
selected chip latches the bus value into the 4-bit I/O output latch on the
clock edge ending X3. Output pins (per `IO_DIR`) reflect the latch from the
next period onward. Repeated WRR instructions simply overwrite the latch
with the most recent value. The manual describes the latch event at X2φ2
(end of X2); because the CPU holds the same value across X2 and X3, latching
at the end of X3 captures the identical value and matches the companion
CPU's documented drive window (10.2).

### 5.4 RDR (read ROM port), encoding 1110 1010

The selected chip drives the port read value onto the bus during X2 and X3;
the CPU samples it on the edge ending X3. The read value per bit is: the
latched output value for pins masked as outputs (`IO_DIR`=1), the value
present on `port_i` for pins masked as inputs (`IO_DIR`=0) — i.e.
`read = (IO_DIR & port_latch) | (~IO_DIR & port_i)`. The manual states the
selected 4001 transfers its I/O pin information to the bus at X2; driving
through X3 as well is the compatible superset that satisfies both the manual
and the companion CPU's end-of-X3 sampling (10.2).

### 5.5 Ignored operations

All other I/O/RAM operations (WRM, WMP, WR0-WR3, SBM, RDM, ADM, RD0-RD3)
target the 4002 and produce no 4001 response. WPM (1110 0011) targets
program-memory RAM behind a 4008/4009 or 4289; the 4001 decodes but ignores
it (the real chip likewise takes no part in WPM transfers). Any fetched word
that is not SRC, WRR, or RDR leaves the I/O select register and port latch
unchanged.

## 6. Reset and Clear Behavior

### 6.1 Historical pins

The manual's 4001 block diagram and text give RESET and CL distinct jobs:
RESET clears the chip's static flip-flops (timing generation, the MTC
output-enable flip-flop, the SRC flip-flop) and inhibits the data-bus
output buffers; the separate CL pin clears the output flip-flops associated
with the I/O lines. Neither affects the mask-programmed ROM contents.

### 6.2 Reconstruction mapping

- `rst_n` low (synchronous, sampled on `clk`): phase counter to A1, word
  address latch to 0, `fetch_selected` cleared, I/O select register cleared
  (hence `io_selected` false for `CHIP_NO` != 0), bus output inhibited
  (`data_oe` = 0). The I/O port latch is deliberately **not** cleared —
  that is CL's function on the real part.
- `clr_n` low (synchronous): the I/O output port latch clears to 4'h0;
  nothing else changes.
- After `rst_n` release the chip is ready for the next A1; with `CHIP_NO`
  = 0 the I/O select register's cleared value (0) matches, so RDR/WRR
  address chip 0 even before the first SRC, exactly as a real power-up
  select register of 0 would.

## 7. Functional Details

### 7.1 Chip select (ROM fetch)

`fetch_selected` is registered at the edge ending A3 from
(`data_i` == `CHIP_NO`) while `cm_rom` is high. It qualifies M1/M2 driving.
The CM-ROM qualification (`cm_rom` sampled high at the A3 edge, tracked in
the companion `cm_rom_seen` flag) prevents response to stray nibbles.

### 7.2 Chip select (I/O port)

The I/O select register is written at the edge ending X2 of a snooped SRC
cycle (no `cm_rom` requirement — see 10.2). `io_selected` = (select
register == `CHIP_NO`). The register is 4 bits wide and holds the last SRC
high nibble until overwritten by a later SRC or cleared by reset.

### 7.3 Port read value

`rdr_value = (IO_DIR & port_latch) | (~IO_DIR & port_i)` — combinational,
evaluated continuously while driving X2/X3.

### 7.4 Bus output multiplexing

| Condition | `data_o` | `data_oe` |
|-----------|----------|-----------|
| Phase M1 and `fetch_selected` and `cm_rom_seen` | ROM word [7:4] | 1 |
| Phase M2 and `fetch_selected` and `cm_rom_seen` | ROM word [3:0] | 1 |
| Phase X2 or X3, snooped RDR, `io_selected` | `rdr_value` | 1 |
| Anything else | 4'h0 | 0 |

At most one chip in a system drives the bus in any period; with several
4001 instances sharing a bus, integration ORs each `data_o` gated by its
`data_oe`.

## 8. Error Handling

There are no error or status outputs. All bus conditions are defined: an
unselected chip stays off the bus; a selected chip with any address
(including 0x00 and 0xFF) returns the masked ROM word; WRR/RDR without a
preceding SRC select chip 0 (select register reset value); SRC/WRR/RDR
decisions rely only on the snooped fetch, so two-cycle or one-cycle
surrounding instructions are irrelevant. CM-ROM absent during A1-A3
inhibits address latching and M1/M2 driving (the manual's "inhibit data
out" behavior of a reset or unqualified chip).

## 9. Constraints

- Synthesis: pure RTL, single clock, synchronous resets; the ROM is a
  constant lookup (packed-parameter select), the port latch and select
  registers are flip-flops; no latches, no inferred RAM arrays.
- Performance: responds within one clock period in every phase; zero
  latency ROM read (combinational mux of the latched address).
- Area: small; exact Yosys cell count recorded in `report/final_report.md`.

## 10. Sources and Interpretations

### 10.1 Sources

- MCS-4 Users Manual (February 1973 revision; scanned original on
  bitsavers), Section IV "4001 - 256 X 8 Mask Programmable ROM and 4 Bit
  I/O Port" (address/chip-number/CSE/MTC/SRC-FF behavior, RESET vs CL
  semantics, per-pin I/O metal options, ordering information) and Section
  II (8-period instruction cycle, SRC timing, 16-chip CM-ROM limit):
  <https://archive.org/details/bitsavers_intelMCS4M_18342130>
  (full text:
  <https://archive.org/stream/bitsavers_intelMCS4M_18342130/MCS-4_UsersManual_Feb73_djvu.txt>).
- MCS-4 Micro Computer Set data sheet, November 1971 (family announcement
  era document describing the 4001 as 2048-bit mask ROM with 4-bit I/O
  port): <https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf>.
- MCS-4 (i4004) system overview with instruction-cycle phase diagram,
  University of Hamburg:
  <https://tams.informatik.uni-hamburg.de/applets/hades/webdemos/80-mcs4/intro/mcs4.html>.
- MCS-40 CPU core behavioral reference (A1/A2/A3 low-to-high address nibble
  order, I/O instruction X2/X3 bus behavior, SRC RC-latch timing): MAME
  mcs40.cpp,
  <https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp>.
- Intel 4004 historical summary (MCS-4 family composition, November 15,
  1971 advertisement in Electronic News, Busicom 141-PF origin and earlier
  1971 delivery): <https://en.wikipedia.org/wiki/Intel_4004> and
  <https://www.edn.com/intel-4004-is-announced-november-15-1971/>.
- Integration contract: the verified `intel_4004` reconstruction on this
  repository's `design/add-intel-4004` branch (bus timing, WRR/RDR drive and
  sample periods) — this chip is timed to interoperate with it directly.

All source content is summarized and rephrased; no source text is reproduced
verbatim beyond device names, signal names, and mnemonics.

### 10.2 Interpretations and deliberate deviations

1. **CM-ROM during SRC.** The manual says the CPU activates CM-ROM (and one
   CM-RAM line) at X2 of SRC, and the 4001 qualifies its select capture on
   CM-ROM presence. The companion `intel_4004` reconstruction instead
   asserts `cm_ram` (bank-decoded) at X2/X3 of SRC and leaves `cm_rom` low.
   To interoperate with both, this chip qualifies the SRC select capture on
   the snooped opcode alone; it never requires `cm_rom` during X2. The
   captured value and "X3 ignored" semantics match the manual either way.
2. **WRR latch and RDR drive periods.** The manual places the WRR latch
   event at the end of X2 and the RDR data at X2; the companion CPU drives
   WRR data through X2 and X3 and samples RDR at the end of X3. Because the
   CPU's WRR value is stable across both periods, latching at the end of
   X3 is equivalent; RDR is driven during both X2 and X3, the compatible
   superset of both contracts.
3. **RESET vs the I/O latch.** The manual assigns I/O-latch clearing to the
   separate CL pin and says RESET clears static flip-flops and inhibits
   data out; it does not state that RESET clears the I/O latch. This model
   follows that split exactly (`rst_n` vs `clr_n`). Systems that tie only
   RESET at power-up therefore start with an indeterminate port latch on
   real silicon; this model defines it as the previous simulation value,
   and designers should pulse `clr_n` for a defined all-zero start.
4. **Announcement date.** November 15, 1971 is the publication date of
   Intel's first MCS-4 advertisement (Electronic News), which the industry
   treats as the family's announcement date; the chips had already been
   delivered to Busicom earlier in 1971, and the November 1971 data sheet
   is the earliest located Intel document in this collection. Some secondary
   sources give slightly different "first public mention" framing; the
   1971 year itself is not in dispute.
5. **Per-pin electrical options** (inversion, pull-up/pull-down resistors)
   are mask options of the real part but are logical no-ops at this level
   of modeling and are out of scope; only the per-pin input/output
   direction option is modeled (`IO_DIR`).

## 11. Out of Scope

- Electrical behavior: PMOS levels, φ1/φ2 non-overlap, 16-pin DIP pinout
  numbering, drive strength, on-chip input resistors, capacitance.
- The dynamic (refreshed) nature of the real ROM array and its two 16 x 64
  cell blocks; this model is static.
- CL pin per-line wiring variants and inversion/pull-up mask options.
- WPM participation (the 4001 has none on the real part).
- Multi-chip arbitration: each instance is independent; bus contention
  avoidance is a system-integration property (formally verified here at
  the single-chip level: drive only when selected).
- CPU-internal micro-operation ordering beyond the externally visible bus
  protocol.
