# Specification: Intel 8259A Programmable Interrupt Controller

## 1. Overview

`intel_8259` is a synthesizable functional reconstruction of the Intel 8259A
Programmable Interrupt Controller (PIC). It accepts up to eight prioritized
interrupt requests, resolves the highest-priority unmasked request, drives an
interrupt line to the CPU, and supplies a programmed interrupt vector during the
CPU acknowledge sequence. It is programmed through a two-address CPU bus using a
sequence of Initialization Command Words (ICW1-ICW4) followed by Operation
Command Words (OCW1-OCW3).

The historical NMOS 8259A has no clock pin and no reset pin; it is asynchronous
and is brought to a defined state only by the ICW1 initialization sequence. This
implementation samples all bus transactions, interrupt-request lines, and the
acknowledge handshake on a single rising clock edge so that it maps reliably to
synchronous logic. A single active-low synchronous reset `rst_n` is added to
force a defined, un-initialized state at power-up. The implementation reproduces
the digital programming model, priority resolution, acknowledge sequencing, and
cascade signaling; it does not reproduce original asynchronous pin timing, pulse
widths, or electrical behavior.

## 2. Features

- Eight interrupt request inputs `IR0`-`IR7` with edge-triggered or
  level-triggered sensing (`LTIM`).
- Interrupt Request Register (IRR), In-Service Register (ISR), and Interrupt
  Mask Register (IMR).
- Priority resolver supporting fully nested priority, automatic rotation,
  specific rotation, and programmable lowest-priority (set-priority) selection.
- CPU interrupt handshake: `INT` request output and `INTA_n` acknowledge input.
- MCS-86/88 mode (two acknowledge pulses, one vector byte) and MCS-80/85 mode
  (three acknowledge pulses, `CALL` opcode plus two address bytes).
- End-of-interrupt handling: non-specific EOI, specific EOI, rotate-on-EOI
  (specific and non-specific), rotate in automatic-EOI mode, and automatic EOI.
- Special mask mode and polled mode.
- Readback of IRR and ISR through OCW3 and IMR through the OCW1 address.
- Cascade signaling: master drives the cascade address bus `CAS[2:0]`; slave
  decodes `CAS[2:0]` against its programmed identity; buffered and non-buffered
  operation with the shared `SP_n`/`EN_n` pin.
- Separate pin input, output, and output-enable vectors for the shared cascade
  and buffer-control pins, for synthesis-friendly bidirectional integration.

## 3. Interfaces

### 3.1 Port list

| Port | Direction | Width | Description |
|---|---|---:|---|
| `clk` | input | 1 | Sampling clock for all bus, request, and acknowledge events |
| `rst_n` | input | 1 | Active-low synchronous reset to the un-initialized state |
| `cs_n` | input | 1 | Active-low CPU chip select |
| `rd_n` | input | 1 | Active-low CPU read strobe |
| `wr_n` | input | 1 | Active-low CPU write strobe |
| `a0` | input | 1 | CPU address line selecting command/register group |
| `data_i` | input | 8 | CPU write data |
| `data_o` | output | 8 | CPU read data and interrupt-vector/opcode output |
| `data_oe` | output | 1 | CPU data-bus output enable, active high |
| `ir` | input | 8 | Interrupt request inputs `IR7:IR0` |
| `int_o` | output | 1 | Interrupt request to the CPU, active high |
| `inta_n` | input | 1 | Interrupt acknowledge from the CPU, active low |
| `cas_i` | input | 3 | Cascade address bus sampled input (slave role) |
| `cas_o` | output | 3 | Cascade address bus drive value (master role) |
| `cas_oe` | output | 3 | Cascade bus output enable, active high |
| `sp_n_i` | input | 1 | Slave-program pin sampled input; `1`=master, `0`=slave in non-buffered mode |
| `en_n_o` | output | 1 | Buffer-enable output value, active low, asserted while the data bus is driven |
| `en_n_oe` | output | 1 | Buffer-enable output enable; high only in buffered mode |

At an integration boundary, each shared physical pin may be represented as
`assign pad = oe ? o : 1'bz; assign i = pad;`. The `SP_n`/`EN_n` pin is an input
(`sp_n_i`) in non-buffered mode and an output (`en_n_o`, enabled by `en_n_oe`) in
buffered mode.

### 3.2 CPU bus protocol

A CPU transaction is accepted on a rising `clk` edge when `cs_n == 0` and exactly
one of `rd_n` or `wr_n` is low.

- Write: `cs_n == 0`, `wr_n == 0`, `rd_n == 1`. Command byte is `data_i`,
  selected by `a0`.
- Read: `cs_n == 0`, `rd_n == 0`, `wr_n == 1`. Read data is combinational while
  the read is asserted; any read side effect (poll acknowledge) occurs on the
  accepting rising edge.
- Idle, deselected, or both strobes low: no CPU transaction is accepted and the
  CPU read bus is not driven by a bus read.

The `INTA_n` acknowledge handshake is independent of `cs_n`. `data_o` is driven
during the acknowledge sequence regardless of `cs_n`, matching the historical
device where the interrupt-acknowledge bus cycle is not chip-select qualified.

### 3.3 Acknowledge (INTA) handshake

The CPU acknowledges an interrupt with a sequence of `INTA_n` pulses. Each
sampled high-to-low transition of `inta_n` is one acknowledge pulse. A pulse must
be represented by at least one sampled-high cycle followed by one sampled-low
cycle.

- MCS-86/88 mode: two pulses. Pulse 1 freezes the request and selects the
  vectoring level; the data bus is not driven. Pulse 2 drives the vector byte.
- MCS-80/85 mode: three pulses. Pulse 1 drives the `CALL` opcode `8'hCD`; pulse 2
  drives the low address byte; pulse 3 drives the high address byte.

The device drives `data_o` only while `inta_n == 0` during a pulse in which it
owns the bus (see Section 8). The acknowledge sequence completes after the final
mode-dependent pulse.

## 4. Register and command map

Writes and reads are decoded by `a0` and, for writes, by data-bit patterns. The
initialization state machine (Section 6) determines whether an `a0 == 1` write is
ICW2, ICW3, or ICW4.

| Access | `a0` | Condition | Meaning |
|---|---:|---|---|
| Write | 0 | `data_i[4] == 1` | ICW1 (starts initialization) |
| Write | 0 | `data_i[4:3] == 2'b00` | OCW2 |
| Write | 0 | `data_i[4:3] == 2'b01` | OCW3 |
| Write | 1 | during initialization | ICW2, then ICW3 (if cascade), then ICW4 (if requested) |
| Write | 1 | after initialization | OCW1 (IMR) |
| Read | 0 | read register selected | IRR or ISR (per OCW3), or poll word if poll is pending |
| Read | 1 | any time | IMR |

## 5. Command word formats

### 5.1 ICW1 (`a0 == 0`, `data_i[4] == 1`)

| Bit | Name | Meaning |
|---:|---|---|
| 7:5 | A7:A5 | MCS-80/85 vector address bits A7:A5; ignored in MCS-86/88 mode |
| 4 | 1 | Identifies ICW1 |
| 3 | LTIM | `1`: level triggered, `0`: edge triggered |
| 2 | ADI | MCS-80/85 call-address interval; `1`: interval of 4, `0`: interval of 8; ignored in MCS-86/88 mode |
| 1 | SNGL | `1`: single 8259A (no ICW3), `0`: cascade (ICW3 required) |
| 0 | IC4 | `1`: ICW4 required, `0`: no ICW4 (ICW4 fields default to 0) |

ICW1 clears IMR, resets the edge-sense latch, sets the lowest-priority level to
`IR7` (so `IR0` is highest priority), clears ISR, clears special mask mode,
clears automatic rotation, and selects IRR for register readback.

### 5.2 ICW2 (`a0 == 1`, first initialization write)

- MCS-86/88 mode: `data_i[7:3]` are vector bits T7:T3. During acknowledge, the
  three low bits are replaced by the interrupt level, giving vector
  `{icw2[7:3], level}`.
- MCS-80/85 mode: `data_i[7:0]` are address bits A15:A8, driven on the third
  acknowledge pulse.

The mode (`µPM`) is known only after ICW4; the raw ICW2 byte is stored and
interpreted per mode at acknowledge time.

### 5.3 ICW3 (`a0 == 1`, only when `SNGL == 0`)

- Master role: `data_i[7:0]` are `S7:S0`; a set bit marks the corresponding IR
  line as having a slave attached.
- Slave role: `data_i[2:0]` are the slave identity `ID2:ID0`; `data_i[7:3]` are
  ignored.

The stored ICW3 byte is interpreted per role (Section 8). ICW3 is skipped when
`SNGL == 1`.

### 5.4 ICW4 (`a0 == 1`, only when `IC4 == 1`)

| Bit | Name | Meaning |
|---:|---|---|
| 7:5 | 0 | Reserved |
| 4 | SFNM | `1`: special fully nested mode |
| 3 | BUF | `1`: buffered mode (`SP_n`/`EN_n` pin is the `EN_n` output) |
| 2 | M/S | In buffered mode, `1`: master, `0`: slave; ignored when `BUF == 0` |
| 1 | AEOI | `1`: automatic end of interrupt |
| 0 | µPM | `1`: MCS-86/88 mode, `0`: MCS-80/85 mode |

When ICW4 is skipped (`IC4 == 0`), all ICW4 fields default to 0 (MCS-80/85 mode,
normal EOI, non-buffered, fully nested).

### 5.5 OCW1 (`a0 == 1`, after initialization)

`data_i[7:0]` load the IMR directly. A set mask bit inhibits the corresponding
interrupt level from generating `INT` and from being selected during acknowledge.
Masking does not clear a pending IRR bit and does not clear an ISR bit.

### 5.6 OCW2 (`a0 == 0`, `data_i[4:3] == 2'b00`)

| Bit | Name |
|---:|---|
| 7 | R (rotate) |
| 6 | SL (specific level) |
| 5 | EOI |
| 4:3 | `00` (identifies OCW2) |
| 2:0 | L2:L0 (level) |

| `{R,SL,EOI}` | Command |
|---|---|
| `001` | Non-specific EOI |
| `011` | Specific EOI to level `L` |
| `101` | Rotate on non-specific EOI |
| `111` | Rotate on specific EOI to level `L` |
| `100` | Set rotate-in-automatic-EOI mode |
| `000` | Clear rotate-in-automatic-EOI mode |
| `110` | Set priority: lowest priority becomes level `L` |
| `010` | No operation |

- Non-specific EOI clears the highest-priority ISR bit currently set.
- Specific EOI clears ISR bit `L`.
- Rotate-on-non-specific-EOI clears the highest-priority ISR bit and makes that
  level the new lowest priority.
- Rotate-on-specific-EOI clears ISR bit `L` and makes `L` the new lowest
  priority.
- Set priority makes `L` the lowest priority without clearing any ISR bit.
- Rotate-in-automatic-EOI set/clear controls whether an automatic EOI also
  rotates priority.

### 5.7 OCW3 (`a0 == 0`, `data_i[4:3] == 2'b01`)

| Bit | Name | Meaning |
|---:|---|---|
| 7 | 0 | Reserved |
| 6 | ESMM | Enable special-mask-mode write |
| 5 | SMM | Special mask mode value (applied only when `ESMM == 1`) |
| 4:3 | `01` | Identifies OCW3 |
| 2 | P | Poll command |
| 1 | RR | Read-register command |
| 0 | RIS | `1`: read ISR, `0`: read IRR (applied only when `RR == 1`) |

- `ESMM == 1` writes special mask mode from `SMM`; `ESMM == 0` leaves it
  unchanged.
- `RR == 1` selects IRR (`RIS == 0`) or ISR (`RIS == 1`) for subsequent
  `a0 == 0` reads. The selection persists until changed.
- `P == 1` arms a poll; the next accepted `a0 == 0` read returns the poll word
  and performs a poll acknowledge (Section 7.5). Poll takes precedence over the
  read-register selection for that read.

## 6. Initialization sequence

Initialization is a state machine advanced by CPU writes:

1. A write with `a0 == 0` and `data_i[4] == 1` is ICW1 and (re)starts
   initialization from any state.
2. The next `a0 == 1` write is ICW2.
3. If `SNGL == 0`, the next `a0 == 1` write is ICW3; otherwise ICW3 is skipped.
4. If `IC4 == 1`, the next `a0 == 1` write is ICW4; otherwise ICW4 is skipped and
   its fields default to 0.
5. After the last required ICW, the device is initialized and accepts OCWs.

While un-initialized (after `rst_n` and before the sequence completes), `INT` is
held inactive and acknowledge sequences do not engage. During initialization,
OCW decoding of `a0 == 0` writes is suspended; an `a0 == 0` write with
`data_i[4] == 1` restarts ICW1 and an `a0 == 0` write with `data_i[4] == 0` is
ignored. `a0 == 1` writes are consumed by the ICW sequence.

Reset (`rst_n == 0`) forces: un-initialized state expecting ICW1, `IMR = 8'hff`,
`IRR = 0`, `ISR = 0`, lowest priority = `IR7`, edge-sense baseline set to the
current `ir` sample, special mask mode off, automatic rotation off, read select
= IRR, no poll pending, and no acknowledge in progress. Setting `IMR` to all-ones
at reset guarantees no interrupt is generated before software initializes the
device; ICW1 then clears IMR to all-zero per the historical device.

## 7. Functional operation

### 7.1 Request sensing

- Edge-triggered (`LTIM == 0`): a sampled low-to-high transition on `ir[i]` sets
  `IRR[i]`. `IRR[i]` remains set until it is cleared by an acknowledge of level
  `i` or by ICW1. A held-high level does not generate repeated requests; a new
  rising edge is required after each acknowledge.
- Level-triggered (`LTIM == 1`): `IRR[i]` follows the sampled `ir[i]` level. A
  level that remains high re-requests after its ISR bit is cleared.

Edge latching is frozen for the acknowledged level between acknowledge pulse 1
and completion of the acknowledge sequence.

### 7.2 Priority resolution

A `lowest_priority` register (0-7) names the level with lowest priority. Priority
from highest to lowest is `(lowest_priority+1) mod 8`, `(lowest_priority+2) mod
8`, ..., `lowest_priority`. Reset and ICW1 set `lowest_priority = 7`, giving the
fully nested order `IR0` (highest) through `IR7` (lowest).

The resolver selects the highest-priority candidate among a set of levels using
this order. `eligible = IRR & ~IMR` is the request candidate set.

### 7.3 Interrupt generation

Let the highest-priority eligible request have priority rank `pend_rank` (rank 1
is highest) and the highest-priority in-service level have rank `isr_rank`
(no ISR set is treated as rank 8+1, i.e., lower than any request).

- Normal fully nested mode: `INT` asserts when an eligible request exists and
  `pend_rank < isr_rank`.
- Special fully nested mode (`SFNM == 1`): the comparison is `pend_rank <=
  isr_rank`, allowing a higher-priority request on a level already in service to
  be recognized (used for cascaded slaves).
- Special mask mode: ISR-based blocking is removed; `INT` asserts whenever any
  eligible request exists.

`INT` is held inactive while the device is un-initialized.

### 7.4 Acknowledge sequencing and EOI

On acknowledge pulse 1, the device latches the resolved eligible level as
`ack_level`, sets `ISR[ack_level]`, and, in edge mode, clears `IRR[ack_level]`.
The selection is frozen for the remainder of the sequence.

- MCS-86/88 mode: pulse 2 completes the sequence.
- MCS-80/85 mode: pulses 2 and 3 complete the sequence.

If automatic EOI (`AEOI == 1`) is enabled, `ISR[ack_level]` is cleared at
completion of the final pulse. If rotate-in-automatic-EOI is also set, the
`ack_level` becomes the new lowest priority. Without AEOI, the ISR bit persists
until an explicit EOI command (Section 5.6).

If no eligible request exists when pulse 1 arrives (a spurious acknowledge), the
device selects the lowest-priority level, drives its vector, and does not set an
ISR bit, matching the historical spurious-interrupt behavior.

### 7.5 Poll mode

When a poll is armed by OCW3, the next accepted `a0 == 0` read returns the poll
word `{I, 4'b0000, W2, W1, W0}`, where `I == 1` when an eligible request exists
and `W` is the binary level of the highest-priority eligible request. The poll
read performs an acknowledge-equivalent action: it sets `ISR[W]` and, in edge
mode, clears `IRR[W]` when `I == 1`. The poll-pending flag is then cleared.

### 7.6 Register readback

- `a0 == 1` read returns IMR.
- `a0 == 0` read returns the poll word when a poll is pending, otherwise IRR or
  ISR according to the OCW3 read select. Reset and ICW1 default the read select
  to IRR.

## 8. Cascade and buffer behavior

The device role is determined by mode:

- Non-buffered (`BUF == 0`): `sp_n_i` selects role. `sp_n_i == 1` is master,
  `sp_n_i == 0` is slave. `en_n_oe == 0` (the pin is an input).
- Buffered (`BUF == 1`): the ICW4 `M/S` bit selects role. `en_n_oe == 1` and
  `en_n_o` is driven low whenever the device drives `data_o`.
- Single mode (`SNGL == 1`): the device behaves as a standalone master with no
  slaves attached, regardless of the role pin.

Cascade address bus:

- Master: when acknowledge pulse 1 selects a level whose ICW3 master bit is set
  (a slave is attached), the master drives `cas_o = ack_level` with `cas_oe =
  3'b111` for the remainder of the acknowledge sequence, and it does not drive
  the vector/address bytes (the slave does). When the selected level has no
  slave, the master drives the vector/address bytes itself and releases the
  cascade bus.
- Slave: `cas_o` is not driven (`cas_oe = 0`). A slave engages the acknowledge
  sequence (sets ISR, clears IRR, drives its vector/address bytes) only when
  `cas_i` equals its programmed identity at acknowledge pulse 1; otherwise it
  ignores the acknowledge entirely.
- Standalone/single: drives the full sequence itself and releases the cascade
  bus.

Data-bus ownership during acknowledge (device drives `data_o` while `inta_n ==
0`):

| Role and selection | Pulse 1 (85 only) | Pulse 2 | Pulse 3 (85 only) |
|---|---|---|---|
| MCS-86/88, owns vector | not driven | vector `{icw2[7:3], level}` | n/a |
| MCS-80/85, owns address | `CALL` `8'hCD` | low address byte | high address byte |
| Master with slave on level | `CALL` (85 only) | not driven | not driven |
| Slave, `cas_i` != identity | not driven | not driven | not driven |

"Owns vector/address" is true for a standalone device, a master whose selected
level has no slave, or a slave whose identity matches `cas_i`. A master always
drives the `CALL` opcode on pulse 1 in MCS-80/85 mode; a slave drives address
bytes on pulses 2 and 3 only.

MCS-80/85 address bytes:

- Interval of 4 (`ADI == 1`): low byte `{icw1[7:5], level, 2'b00}`.
- Interval of 8 (`ADI == 0`): low byte `{icw1[7:6], level, 3'b000}`.
- High byte: `icw2[7:0]`.

## 9. Ordering and edge cases

Within one sampled cycle the priority of effects is:

1. reset has highest priority;
2. an ICW1 write restarts initialization and suppresses other command decoding;
3. an accepted acknowledge pulse updates ISR/IRR and the acknowledge phase;
4. an accepted CPU write (ICW2-ICW4, OCW1-OCW3) updates the addressed state;
5. an accepted poll read performs its acknowledge-equivalent update.

A simultaneous acknowledge pulse and CPU access to conflicting state is avoided
by the environment; the deterministic rules above define the outcome if it
occurs. Invalid simultaneous `rd_n` and `wr_n` low is not an accepted CPU
transaction and produces no bus-read data drive.

## 10. Timing requirements

- All state changes occur on rising `clk` edges.
- CPU control, address, and write data must satisfy setup/hold around that edge.
- An `INTA_n` pulse and each interrupt-request edge must be represented by at
  least one sampled-high cycle and one sampled-low cycle.
- Read data, vector/opcode data, output enables, `INT`, and the cascade/buffer
  outputs are combinational functions of registered state and current
  bus/pin inputs.
- No internal synchronizers are provided; asynchronous request and acknowledge
  inputs must be synchronized by the integrator or the clock must be slow enough
  to meet the sampling requirement.

## 11. Scope exclusions

The following original-device characteristics are outside scope:

- NMOS process behavior, TTL voltage levels, drive current, and fan-out;
- 28-pin DIP package pin numbering and electrical compatibility;
- original asynchronous pulse-width, propagation-delay, and recovery
  specifications;
- metastability protection and clock-domain-crossing circuitry;
- multi-chip system behavior beyond the single-device cascade signaling defined
  in Section 8;
- behavior of undocumented or electrically illegal bus combinations beyond the
  deterministic rules defined above.

## 12. References

- [Intel 8259A datasheet reproduction (pcjs.org archive)](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf)
- [Intel "Programming the 8259A" application note archive](http://www.idc-online.com/technical_references/pdfs/electronic_engineering/Programming_THE_8259A.pdf)
- [8259A device summary, alldatasheet](http://www.alldatasheet.com/datasheet-pdf/pdf/66107/INTEL/8259A.html)
- [8259 historical summary and MCS-85 introduction date](https://en.wikipedia.org/wiki/Intel_8259)

Source content is summarized and rephrased for licensing compliance; no source
text is reproduced verbatim beyond device names and signal terminology.
