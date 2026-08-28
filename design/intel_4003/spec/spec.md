# Specification: Intel 4003

## 1. Overview

The Intel 4003 is the I/O expander of the 1971 MCS-4 four-chip set (4004 CPU,
4001 ROM, 4002 RAM, 4003 shift register). It is a **10-bit static serial-in /
parallel-out / serial-out shift register with enable logic**, used to stretch
the single 4-bit I/O port of a 4001 ROM or 4002 RAM into arbitrarily many
output lines for keyboards, printers, displays and other peripherals — most
famously the printer and keyboard matrix of the Busicom 141-PF calculator.

A program streams data bits into the register by toggling two port lines (a
serial DATA IN line and a CP clock-pulse line); the ten register stages are
continuously presented on ten parallel output lines behind a shared enable,
and a serial output allows any number of 4003s to be chained into registers
whose length is a multiple of ten.

This specification defines the behavioral contract implemented by
`src/intel_4003.sv`. It is a synchronous, synthesizable functional
reconstruction of the part's architecture, not an electrical or transistor
model. Where the historical device is asynchronous (a free-running CP input,
an internal power-on-clear, PMOS voltage conventions), this core takes
documented synchronous liberties that are listed in section 9 and section 12.

**Width note (researched, not assumed).** Informal summaries sometimes
describe the 4003 as a "16-bit shift register". The primary sources are
unanimous that it is a **10-bit** part:

- The MCS-4 Users Manual (February 1973), section VI, is titled "4003 10-BIT
  SERIAL-IN/PARALLEL-OUT, SERIAL-OUT SHIFT REGISTER" and states the device is
  a 10-bit serial-in, parallel-out, serial-out shift register with enable
  logic, with data loaded serially and read out on ten parallel lines.
- The same manual's block diagram (Fig. 8) shows ten stages with parallel
  outputs Q0-Q9, and its cascade note says chaining yields "length multiples
  of 10".
- The November 1971 MCS-4 data sheet's 4003 page describes the same
  ten-stage register with power-on clear (the scanned original is on the
  DeRamp.com MCS-4 archive page).
- MAME's Busicom 141-PF driver masks its 4003 keyboard shifter state with
  0x3FF — ten bits — and models the printer shifter identically.
- The IEEE Computer Society's oral-history-derived article "The History of
  the 4004" (Faggin, Hoff, Mazor, Shima) describes the 4003 as a 10-bit
  serial-in/parallel-out, serial-out shift register.
- A package check agrees: the 16-pin DIP has exactly enough pins for Vdd,
  Vss, DATA IN, CP, ENABLE, SERIAL OUT and ten Q outputs — a "16 parallel
  output" part could not fit the package.

This design therefore implements the authentic 10-bit organization. The
`WIDTH` parameter defaults to the authentic value; it exists for formal
experimentation only and is not a multi-chip cascade substitute (a cascade of
N parts has N separate 10-line output groups, which a single wider register
cannot model).

## 2. Features

- 10-bit static shift register (single-phase clocked; contents are retained
  indefinitely without refresh).
- Serial input (DATA IN), serial output (SERIAL OUT) for indefinite
  cascading in multiples of ten stages.
- Ten parallel output lines Q0-Q9 driven from the register stages.
- Enable gating of the parallel outputs only: with the enable deasserted the
  Q lines present the inactive level while the register keeps shifting and
  SERIAL OUT keeps streaming.
- Shifts once per CP pulse; CP is independent of the MCS-4 two-phase system
  clock (the historical part does not use φ1/φ2 or SYNC at all).
- Data-in set-up is tolerant of DATA IN changing simultaneously with CP (the
  historical part delays CP internally; this core samples synchronously, see
  section 6.3).
- Active-low synchronous reset (reconstruction addition replacing the
  historical internal power-on-clear, see section 8).

## 3. Interfaces

### 3.1 Port List

| Port | Direction | Width | Historical pin | Description |
|------|-----------|-------|----------------|-------------|
| `clk` | input | 1 | — (none) | System clock. Reconstruction addition: every rising edge ends one MCS-4 clock period, matching the `intel_4004` core convention. |
| `rst_n` | input | 1 | — (none) | Active-low synchronous reset. Reconstruction addition replacing the internal power-on-clear (section 8). |
| `cp_i` | input | 1 | CP | Shift clock pulse. One shift per rising edge of CP; edge-detected against `clk` (section 6.2). |
| `data_in_i` | input | 1 | DATA IN | Serial data input; the value present at a shift event enters stage 0. |
| `en_i` | input | 1 | ENABLE | Output enable, active high in RTL logic. Gates only Q0-Q9 (section 6.4). |
| `q_o` | output | 10 | Q0-Q9 | Parallel outputs; `q_o[i]` mirrors register stage i. |
| `so_o` | output | 1 | SERIAL OUT | Serial output = stage 9; unaffected by the enable; feeds the next 4003's DATA IN in a cascade. |

### 3.2 Polarity and logic conventions

The MCS-4 uses negative logic on its pins (the Users Manual defines logic "1"
as the more negative voltage and logic "0" as Vss). As with the
`intel_4004` reconstruction, all RTL signals here use positive logic: an
asserted control or a data "1" is `1'b1`. The ENABLE pin is active-low in
*voltage* (enabled when the pin is pulled to the more negative level, which
the manual writes as "E = low"), i.e. active-high in the MCS-4 logic
convention; `en_i` mirrors that logic convention directly: `en_i = 1` means
outputs enabled. With the enable deasserted the historical outputs sit at
the Vgg potential, which is the deasserted (logic "0") level in the MCS-4
negative-logic pin convention; this core drives `q_o` to all-zero bits in
that state. The wired-signature trick this enables on real hardware
(up to three tied outputs reading "at least one asserted") is an electrical
behavior and is out of scope.

### 3.3 How the 4003 connects in an MCS-4 system

The 4003 has no bus pins. It hangs off the 4-bit I/O port of a 4001 ROM chip
(written with WRR, `cm_rom` context) or the 4-bit output port of a 4002 RAM
chip (written with WMP, `cm_ram` context):

- one port line drives DATA IN of the first 4003 in the chain;
- another port line drives CP of every 4003 in the chain (shared clock);
- optionally a third port line drives ENABLE of the group;
- SERIAL OUT of each 4003 feeds DATA IN of the next.

The MCS-4 Users Manual's Fig. 9 shows exactly this pattern with four 4003s
(40 stages) fed from two RAM output ports: one port supplies the data bit,
the other supplies clock pulses. MAME's Busicom 141-PF driver wires the ROM0
I/O port the same way: bit 0 clocks the keyboard shifter, bit 1 is the
shared serial data bit, bit 2 clocks the printer shifter. This
repository's convention is shown below; the TB uses it for every test:

| Port bit | Signal driven |
|----------|---------------|
| 0 | CP of all chained 4003s |
| 1 | DATA IN of the first 4003 |
| 2 | ENABLE of the group (1 = outputs on) |
| 3 | unused in this design's examples |

Each port-write instruction is a full 8-phase MCS-4 instruction cycle; the
port latch updates at the edge ending X3 (section 6.1).

## 4. Architecture

### 4.1 Registers

| Resource | Width | Reset value | Description |
|----------|-------|-------------|-------------|
| `sr[0]`..`sr[9]` | 1 each | 0 | Shift register stages. `sr[0]` is nearest DATA IN; a shift moves `sr[i]` into `sr[i+1]` and DATA IN into `sr[0]`. `sr[9]` drives SERIAL OUT. |
| `cp_prev` | 1 | 0 | Registered previous-sample of CP, used for synchronous rising-edge detection (reconstruction addition, section 6.2). |

The historical part has exactly the ten stages; `cp_prev` is bookkeeping
introduced by the synchronous CP sampling model and has no architectural
effect (section 6.2).

### 4.2 Data Flow

Data enters serially at stage 0 and migrates toward stage 9 at one stage per
CP pulse; after k pulses the k most recent input bits occupy `sr[k-1:0]`
(lowest index = most recent). Bits pushed past stage 9 leave the register
through SERIAL OUT, which is why a chain of 4003s behaves as one long shift
register. The Q outputs continuously expose all ten stages (when enabled),
so the parallel word "appears" incrementally during a load and is complete
once the chosen number of pulses has been applied — there is no separate
load or latch strobe.

Bit-order convention: to end up with a desired word `W = {W9..W0}` on
Q0-Q9 after exactly ten pulses, the program sends `W9` first and `W0` last
(first-sent bits travel furthest). Sending LSB-first produces the mirrored
word; the order is entirely a software decision.

## 5. Register Map

None. The 4003 is not addressable; it is pure unclocked-latch I/O hardware
driven through port lines.

## 6. Timing and Operational Rules

### 6.1 Relation to the 8-phase instruction cycle

The historical 4003 uses neither φ1/φ2 nor SYNC (the Users Manual notes
explicitly that the 4003, being a static shift register, does not use the
two system clocks). Its inputs change only when a program writes the driving
port, which happens at the end of an instruction cycle: per the `intel_4004`
specification (section 6.3), write-type port instructions drive the
accumulator nibble on the data bus during X2 and X3 with the appropriate
command line active, and the port latches the nibble at the single edge
ending X3. Consequences modeled here:

- Port lines (hence `cp_i`, `data_in_i`, `en_i`) change only on edges that
  end X3 and then hold for at least one full instruction cycle (8 `clk`
  periods).
- Minimum CP high or low time in this model is one `clk` period. The
  historical limit of interest is a *maximum* CP pulse width of 10 ms
  (a static-DRAM artifact of the real part); it has no synchronous-model
  equivalent and is out of scope.

### 6.2 CP edge detection (reconstruction model)

The real CP pin is an asynchronous edge input. This core samples CP on
`clk` and shifts when the sampled value is high while the previously
registered sample was low (`shift_pulse = cp_i && !cp_prev`), so:

- exactly one shift occurs per CP pulse, even if CP stays high for many
  clock periods (a port latch holds the line high until the next write);
- a pulse need only be one `clk` period wide to be seen;
- the shift commits at the `clk` edge ending the first CP-high period.

`cp_prev` is updated from CP on every non-reset edge.

### 6.3 DATA IN sampling vs. CP ("simultaneous" case)

The data sheet states DATA IN and CP may change simultaneously and that CP
is internally delayed to avoid a race, i.e. the data bit presented together
with (or before) the CP rising edge is the bit captured. The synchronous
equivalent falls out of 6.2: the shift commits at the edge ending the first
CP-high `clk` period, sampling the `data_in_i` value driven *before* that
edge. A program that writes DATA IN and CP in the same port write (both
latched at the same end-of-X3 edge) therefore gets the new data bit
captured by that CP pulse — matching the historical intent.

### 6.4 Enable and SERIAL OUT

- `en_i = 1`: each `q_o[i]` equals stage i, combinationally, every cycle.
- `en_i = 0`: `q_o` is all zeros (the historical deasserted level, section
  3.2). The register continues to shift on CP pulses and SERIAL OUT
  continues to track stage 9 — the Users Manual states the serial-out line
  is not affected by the enable logic, and shifting is controlled by CP
  alone.
- `so_o` always equals `sr[9]`, with no enable dependence and no extra
  delay relative to shifts.

### 6.5 Cascade operation

Connecting `so_o` of one 4003 to `data_in_i` of the next (all parts sharing
CP and ENABLE) yields a shift register of length 10N. The Users Manual
states an indefinite number of devices may be cascaded to provide length
multiples of ten. No RTL parameter participates in cascading; it is external
wiring, exactly as on the real part. The testbench chains two instances and
scores the pair as a single 20-stage register.

### 6.6 Shift summary

| Condition at a `clk` edge | Effect |
|---------------------------|--------|
| `rst_n = 0` | `sr` and `cp_prev` clear; no shift regardless of CP. |
| `rst_n = 1`, `cp_i = 1`, `cp_prev = 0` | Shift: `sr <= {sr[8:0], data_in_i}`. |
| `rst_n = 1`, otherwise | Hold: `sr` unchanged (CP low, or CP still high from the previous cycle). |

`q_o` and `so_o` are combinational functions of `sr` and `en_i` at all
times.

## 7. Error Handling

There are no status or error outputs. All conditions are architecturally
defined: extra CP-high cycles cause no extra shifts (6.2), and data shifted
out of stage 9 is simply gone (recoverable only by re-shifting it through
the chain in reverse order, which real software never does).

## 8. Reset Behavior

The historical 4003 has no reset pin; it contains an internal power-on-clear
circuit that holds the shift register cleared (all stages at the logic-0
potential) from power application until the first CP pulse. This core
replaces that with a conventional synchronous active-low `rst_n`:

- every clock edge on which `rst_n` is sampled low clears `sr` and
  `cp_prev` at that edge; consequently the state is zero in every cycle
  that follows a reset cycle, including when reset is re-asserted mid-run
  (the clearing is synchronous, so the single cycle during which `rst_n`
  first falls is not yet cleared);
- after release the register stays zero until the first CP pulse;
- `rst_n` mid-stream clears the register immediately (synchronously) — a
  testbench-exercised stand-in for the (uncontrollable) power-on-clear.

The power-on-clear's "clears before the first CP" sequencing is preserved
behaviorally by holding `rst_n` low through system start-up, as the MCS-4
RESET line does for the whole chip set.

## 9. Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `WIDTH` | 10 | >= 2 | Stage count. The authentic device is 10; other values are for verification experiments only (see the width note in section 1). Not a cascade primitive. |

## 10. Constraints

- Pure RTL: single clock, synchronous reset, no latches, no memories, no
  tri-states (the shared-wire behavior of real Q lines is a board-level
  electrical property, out of scope).
- Area: a 10-bit shift register plus output gating; Yosys cell count is
  recorded in `report/final_report.md`.
- Performance: one shift maximum per `clk` period; fully static.

## 11. Out of Scope

- Electrical behavior: PMOS levels, Vgg disable potential, push-pull ratio
  output drivers, wired-output key-scanning tricks, input capacitance, the
  16-pin package and pin numbering.
- The 10 ms maximum CP pulse width (a dynamic-latch artifact) and any other
  absolute-time limits; the synchronous model has no long-time failure mode.
- Asynchronous CP timing: pulses shorter than one `clk` period are not
  guaranteed to be seen (section 6.2).
- Analog power-on detection: `rst_n` is an ordinary synchronous input.

## 12. Interpretations and Deviations (summary)

1. **10-bit width, not 16** — per the primary sources listed in section 1;
   the task brief's "16-bit" description conflicts with every authoritative
   source found and with the 16-pin package.
2. **Serial 1-bit DATA IN, not a 4-bit nibble load** — the part is loaded
   bit-serially through a port line under program control; the CPU's 4-bit
   port nibble is demultiplexed on the board (one bit per 4003 input line).
   The per-instruction-nibble load model was considered and rejected: it is
   contradicted by the manual's serial-load description, the MAME shifter
   model (one bit per port write) and the package pin budget.
3. **`clk`/`rst_n` additions** — the real part is clocked only by CP and
   cleared only by power-on logic; a synchronous model needs a sampling
   clock and a defined reset. Both are documented reconstructions.
4. **Synchronous CP edge detection** replaces the internal CP delay line;
   the observable contract (one shift per pulse, simultaneous DATA IN is
   safe) is preserved.
5. **Enable polarity**: active-high in RTL (`en_i`), which equals the
   manual's logic convention for the active-low-voltage ENABLE pin
   (section 3.2).

## 13. Sources

- MCS-4 Micro Computer Set Users Manual, February 1973 (scanned original;
  OCR text via archive.org item `bitsavers_intelMCS4M_18342130`), section VI
  "4003 10-BIT SERIAL-IN/PARALLEL-OUT, SERIAL-OUT SHIFT REGISTER" (device
  description, enable/serial-out rules, CP control, power-on clear, cascade,
  Fig. 8 block diagram, Fig. 9 four-chip system), section V/C logic
  definitions (negative logic), and the system-timing note that the 4003
  does not use the two-phase clocks:
  <http://codeabbey.github.io/heavy-data-1/msc4-manual.pdf>,
  <https://archive.org/stream/bitsavers_intelMCS4M_18342130/MCS-4_UsersManual_Feb73_djvu.txt>
- MCS-4 Micro Computer Set data sheet, November 1971 (scanned; 4003 page
  with power-on-clear description): DeRamp.com MCS-4 archive,
  <https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf>
- MAME Busicom 141-PF driver (`src/mame/skeleton/busicom.cpp`): 4003s are
  modeled as 10-bit shifters (`0x3FF` mask) clocked by ROM-port bits with a
  shared serial-data bit; the in-driver FIXME notes no standalone i4003
  device exists in MAME:
  <https://github.com/mamedev/mame/blob/master/src/mame/skeleton/busicom.cpp>
- TAMS Hades MCS-4 applet notes (i4003): 10-bit serial-in/parallel-out
  shift register, shift on CP rising edge, enable gates only the outputs,
  cascade via SERIAL OUT, clock from one I/O port and data from another:
  <https://tams.informatik.uni-hamburg.de/applets/hades/webdemos/80-mcs4/i4003/i4003-test.html>
- "The History of the 4004", IEEE Micro (Faggin, Hoff, Mazor, Shima, 1996):
  the 4003 is a 10-bit serial-in/parallel-out/serial-out shift register used
  for keyboard scanning and printer control:
  <https://www.computer.org/csdl/magazine/mi/1996/06/m6010/13rRUytWFdY>
- cpu-galaxy.at MCS-4 section: 4003 listed as "10-bit Serial-in/Parallel-out,
  Serial-out MOS Shift Register":
  <https://www.cpu-galaxy.at/CPU/Intel%20CPU/4001-4003/MCS-4%20Section.htm>
- MCS-4 family launch date (November 15, 1971, Electronic News
  advertisement; the November 1971 data catalog already includes the 4003):
  EDN, "Intel 4004 is announced, November 15, 1971",
  <https://www.edn.com/intel-4004-is-announced-november-15-1971/>; Intel
  Virtual Vault, <https://www.intel.com/content/www/us/en/history/virtual-vault/articles/the-intel-4004.html>

Source content is summarized and rephrased for licensing compliance; no
source text is reproduced verbatim beyond device and signal names.
