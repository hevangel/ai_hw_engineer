# Specification: Intel 8251 / 8251A Universal Synchronous / Asynchronous Receiver Transmitter

## 1. Overview

The Intel 8251 and its refined successor the 8251A are programmable serial
communication peripherals (USARTs). The CPU writes parallel characters to the
device and the device serializes them onto `TxD`; the device deserializes `RxD`
into parallel characters that the CPU reads back. Character format, parity,
stop-bit count, baud-rate clock division, and synchronous versus asynchronous
framing are all programmed at run time through a short instruction sequence
written to a single control port.

This specification defines the behavioral contract implemented by
`src/intel_8251.sv`. It is a synchronous, synthesizable functional
reconstruction of the digital programming model, not a pin-level or electrical
model of the NMOS part. Section 11 lists what is deliberately out of scope.

## 2. Features

- Asynchronous framing: start bit, 5 to 8 data bits, optional parity, and 1,
  1.5, or 2 stop bits.
- Synchronous framing: contiguous characters with no start or stop bits, single
  or double sync character, internal or external sync detection, and automatic
  sync-character fill on transmitter underrun.
- Baud-rate clock division of 1x, 16x, or 64x in asynchronous mode; 1x in
  synchronous mode.
- Odd or even parity generation and checking.
- Parity, overrun, and framing error flags with a software error-reset command.
- Break transmission and, in asynchronous mode, break detection.
- Double-buffered transmit and receive data paths.
- `TxRDY`, `TxEMPTY`, and `RxRDY` handshake outputs plus a readable status byte.
- Modem control: `DTR` and `RTS` outputs under software control, `DSR` readable
  in status, and `CTS` gating the transmitter.
- Software internal reset that returns the device to the mode-instruction state.

## 3. Interfaces

### 3.1 Port list

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Core clock. All state changes occur on the rising edge. |
| `rst_n` | input | 1 | Synchronous active-low reset. |
| `cs_n` | input | 1 | Chip select, active low. |
| `rd_n` | input | 1 | Read strobe, active low. |
| `wr_n` | input | 1 | Write strobe, active low. |
| `c_d` | input | 1 | Control/Data select. 1 selects the control/status port, 0 selects the data port. |
| `data_i` | input | 8 | CPU write data. |
| `data_o` | output | 8 | CPU read data. |
| `data_oe` | output | 1 | Asserted while the device drives read data. |
| `txc_tick` | input | 1 | Transmitter baud-clock enable. One pulse per historical `TxC` active edge. |
| `rxc_tick` | input | 1 | Receiver baud-clock enable. One pulse per historical `RxC` active edge. |
| `txd` | output | 1 | Serial transmit data. Idle (mark) level is 1. |
| `txrdy` | output | 1 | Transmit buffer ready for a CPU character. |
| `txempty` | output | 1 | Transmitter has no data to send. In synchronous mode this also flags underrun. |
| `rxd` | input | 1 | Serial receive data. |
| `rxrdy` | output | 1 | A received character is available to the CPU. |
| `syndet_i` | input | 1 | External sync-detect input, used when synchronous mode selects external detection. |
| `syndet_o` | output | 1 | Sync-detect output in synchronous mode, break-detect output in asynchronous mode. |
| `syndet_oe` | output | 1 | Asserted when the device drives the shared `SYNDET`/`BD` pin. |
| `cts_n` | input | 1 | Clear to send, active low. Gates transmission. |
| `dsr_n` | input | 1 | Data set ready, active low. Readable in status. |
| `rts_n` | output | 1 | Request to send, active low. Driven from the command instruction. |
| `dtr_n` | output | 1 | Data terminal ready, active low. Driven from the command instruction. |

The historical part multiplexes the CPU data bus and the `SYNDET`/`BD` pin. This
reconstruction replaces each shared pin with an input, an output, and an
output-enable so no tristate driver appears in the RTL.

The historical part uses `TxC` and `RxC` as free-running baud-rate clock inputs
and a separate `CLK` pin for internal timing. This reconstruction keeps the
single `clk` domain and models `TxC` and `RxC` as clock enables: the environment
asserts `txc_tick` or `rxc_tick` for exactly one `clk` cycle per baud-clock
active edge. All serial bit timing is expressed as a count of those enables.

### 3.2 CPU bus protocol

A cycle is decoded combinationally from the strobes:

- read: `!cs_n && !rd_n && wr_n`
- write: `!cs_n && rd_n && !wr_n`

Any other combination is inactive; simultaneous read and write is inactive. A
write takes effect on the next rising edge of `clk`. A read drives `data_o` with
`data_oe` asserted for as long as the read cycle is decoded, and its side
effects take effect on the next rising edge.

| `c_d` | Cycle | Operation |
|---|---|---|
| 0 | write | Load the transmit data buffer. |
| 0 | read | Return the receive data buffer and clear `RxRDY`. |
| 1 | write | Mode instruction, sync character, or command instruction, according to the programming sequence position. |
| 1 | read | Return the status byte and clear the `SYNDET` status bit. |

### 3.3 Baud-rate clock enables

`txc_tick` and `rxc_tick` are independent. Each is counted down by the
programmed division factor to produce bit boundaries:

| Mode field `B2 B1` | Meaning | Ticks per bit | Ticks per half bit |
|---|---|---:|---:|
| `00` | Synchronous mode | 1 | 1 |
| `01` | Asynchronous, 1x | 1 | 1 |
| `10` | Asynchronous, 16x | 16 | 8 |
| `11` | Asynchronous, 64x | 64 | 32 |

## 4. Register and port map

The device presents two addresses. Which control register a control write
targets is determined by the position in the programming sequence, not by an
address.

| Port | Write target | Read source |
|---|---|---|
| Data (`c_d == 0`) | Transmit buffer | Receive buffer |
| Control (`c_d == 1`) | Mode instruction, sync character 1, sync character 2, or command instruction | Status byte |

## 5. Instruction and status formats

### 5.1 Mode instruction, asynchronous (`data_i[1:0] != 00`)

| Bits | Name | Meaning |
|---|---|---|
| `[1:0]` | `B2 B1` | Baud-rate factor: `01` = 1x, `10` = 16x, `11` = 64x. |
| `[3:2]` | `L2 L1` | Character length: `00` = 5, `01` = 6, `10` = 7, `11` = 8 data bits. |
| `[4]` | `PEN` | 1 enables parity generation and checking. |
| `[5]` | `EP` | 1 selects even parity, 0 selects odd parity. |
| `[7:6]` | `S2 S1` | Stop bits: `01` = 1, `10` = 1.5, `11` = 2. `00` is documented as illegal and is treated as 1 stop bit. |

### 5.2 Mode instruction, synchronous (`data_i[1:0] == 00`)

| Bits | Name | Meaning |
|---|---|---|
| `[1:0]` | `B2 B1` | `00` selects synchronous mode. |
| `[3:2]` | `L2 L1` | Character length, encoded as in section 5.1. |
| `[4]` | `PEN` | 1 enables parity generation and checking. |
| `[5]` | `EP` | 1 selects even parity, 0 selects odd parity. |
| `[6]` | `ESD` | 0 selects internal sync detection and makes `SYNDET` an output; 1 selects external sync detection and makes `SYNDET` an input. |
| `[7]` | `SCS` | 1 selects single sync character, 0 selects double sync character. |

### 5.3 Sync characters

In synchronous mode the mode instruction is followed by one sync character when
`SCS == 1`, or two sync characters when `SCS == 0`. The characters are written
to the control port. Only the low `L` bits of each sync character participate in
detection and in underrun fill, where `L` is the programmed character length.

The datasheet initialization flow branches only on the sync-character count, so
this specification consumes the sync-character writes whenever synchronous mode
is programmed, including when `ESD == 1`. In that configuration the stored
characters are not used for detection because character sync arrives on the
`SYNDET` input. The datasheet wording is ambiguous on this point; the behavior
chosen here is stated so it can be checked rather than inferred.

### 5.4 Command instruction

| Bit | Name | Meaning |
|---|---|---|
| `[0]` | `TxEN` | Transmit enable. |
| `[1]` | `DTR` | 1 drives `dtr_n` low. |
| `[2]` | `RxE` | Receive enable. |
| `[3]` | `SBRK` | Send break: forces `txd` low. |
| `[4]` | `ER` | Error reset: clears the parity, overrun, and framing error flags. Acts once, at the write. |
| `[5]` | `RTS` | 1 drives `rts_n` low. |
| `[6]` | `IR` | Internal reset: returns the device to the mode-instruction state. Acts once, at the write. |
| `[7]` | `EH` | Enter hunt: in synchronous mode, restarts the search for the sync pattern and clears the `SYNDET` status bit. Acts once, at the write, and is ignored in asynchronous mode. |

Bits `[0]`, `[1]`, `[2]`, `[3]`, and `[5]` are retained as persistent controls.
Bits `[4]`, `[6]`, and `[7]` are actions taken at the write; their stored values
carry no behavior. `IR` takes precedence over every other bit in the same
command word.

### 5.5 Status byte

| Bit | Name | Value |
|---|---|---|
| `[0]` | `TxRDY` | 1 when the transmit buffer is empty. Unlike the `txrdy` output, this bit is not conditioned by `TxEN` or `CTS`. |
| `[1]` | `RxRDY` | 1 when a received character is waiting in the receive buffer. |
| `[2]` | `TxEMPTY` | 1 when the transmit buffer is empty and the shifter is idle, or when the synchronous transmitter has underrun. |
| `[3]` | `PE` | Parity error. Set on a parity mismatch, cleared by `ER` or reset. |
| `[4]` | `OE` | Overrun error. Set when a character is delivered while the previous one is still unread, cleared by `ER` or reset. |
| `[5]` | `FE` | Framing error. Set when an asynchronous stop bit samples low, cleared by `ER` or reset. |
| `[6]` | `SYNDET`/`BD` | In synchronous mode, sync detected; cleared by a status read or reset. In asynchronous mode, break detected; cleared when `RxD` returns high or by reset. |
| `[7]` | `DSR` | 1 when `dsr_n` is low. |

## 6. Programming sequence

The device holds a four-state programming pointer:

| State | Control write target | Next state |
|---|---|---|
| `StMode` | Mode instruction | `StSync1` if synchronous mode, otherwise `StCmd` |
| `StSync1` | Sync character 1 | `StCmd` if `SCS == 1`, otherwise `StSync2` |
| `StSync2` | Sync character 2 | `StCmd` |
| `StCmd` | Command instruction | `StMode` if `IR` is set, otherwise `StCmd` |

Reset or an internal reset command sets the pointer to `StMode`. The device is
`configured` only in `StCmd`; the transmitter and receiver are held idle before
that. Any number of command instructions may follow.

## 7. Transmitter

### 7.1 Buffering and handshake

A CPU data write loads the transmit buffer and marks it full. The transmitter
consumes the buffer at a character boundary, which frees it for the next
character. A CPU data write that lands in the same clock cycle as a consume
still leaves the buffer full, so no character is lost.

- `txrdy` output: `buffer empty && configured && TxEN && !cts_n`
- `TxRDY` status bit: `buffer empty`
- `txempty` output and status bit: `(buffer empty && shifter idle) || (synchronous mode && underrun)`

### 7.2 Asynchronous transmission

A character launches on a `txc_tick` when the transmitter is idle, configured,
`TxEN` is set, `cts_n` is low, `SBRK` is clear, and the buffer is full. The
frame is then driven one phase at a time, each phase lasting a whole number of
`txc_tick` pulses:

1. start bit, low, for one bit period;
2. `L` data bits, least significant first, one bit period each;
3. the parity bit if `PEN` is set, one bit period;
4. the stop phase, high, for `1`, `1.5`, or `2` bit periods per `S2 S1`.

The 1.5-bit stop phase is one bit period plus one half-bit period. In 1x
division a half bit is not representable, so the half-bit period equals one
tick and a 1.5-bit stop phase occupies two bit times. This degenerate
combination is accepted rather than rejected.

Between characters `txd` is held high. `SBRK` forces `txd` low regardless of the
transmitter state and prevents a new character from launching.

### 7.3 Synchronous transmission

There is no start or stop bit; characters are contiguous. At every character
boundary, including the boundary that ends the previous character, the
transmitter reloads:

- if the buffer is full, the buffered character is sent and the underrun flag
  clears;
- otherwise a sync character is sent as fill and the underrun flag sets. With a
  double sync character the fill alternates between sync character 1 and sync
  character 2; loading a real character restarts that alternation at sync
  character 1.

Each character consists of `L` data bits, least significant first, followed by
the parity bit if `PEN` is set. If `TxEN` goes low or `cts_n` goes high at a
character boundary, the transmitter returns to idle and holds `txd` high.

## 8. Receiver

### 8.1 Enable and idle state

The receiver runs only when the device is configured and `RxE` is set.
Otherwise it is forced to its idle state, which is start-bit search in
asynchronous mode and hunt in synchronous mode, and its partial character state
is cleared.

### 8.2 Asynchronous reception

1. Search: on an `rxc_tick` with `rxd` low, arm a half-bit delay.
2. Verify: after the half-bit delay, resample `rxd`. If it is high the start bit
   was false and the receiver returns to search. If it is low the start bit is
   accepted.
3. Data: sample `L` bits at one-bit-period intervals, least significant first.
4. Parity: if `PEN` is set, sample the parity bit and set `PE` on a mismatch
   against the expected parity of the sampled data bits.
5. Stop: sample the stop bit. A low sample sets `FE`. The assembled character is
   then delivered and the receiver returns to search.

In 1x division the half-bit delay is one tick, so the verify step resamples one
tick after the search sample rather than at the centre of the bit. External bit
synchronization is assumed in that mode, matching the historical part.

### 8.3 Synchronous reception

While hunting with internal detection, each `rxc_tick` shifts `rxd` into a
16-bit window. The window is compared against the low `L` bits of sync
character 1, or against sync character 1 immediately followed by sync
character 2 when `SCS == 0`. Parity bits are not part of the comparison. On a
match the `SYNDET` status bit sets, the pattern itself is not delivered to the
CPU, and character assembly begins with the next bit.

While hunting with external detection, a high on `syndet_i` sets the `SYNDET`
status bit and starts character assembly with the next bit.

Once synchronized, characters are assembled contiguously: `L` data bits, then
the parity bit if `PEN` is set, then delivery and immediately the next
character. The `EH` command returns the receiver to hunt and clears the
`SYNDET` status bit.

### 8.4 Delivery, overrun, and character width

Delivery writes the right-aligned assembled character into the receive buffer
and asserts `RxRDY`. Unused high bits of a character shorter than 8 bits read
back as zero.

If the buffer is still full at delivery, `OE` is set and the previous character
is overwritten. A CPU data read in the same clock cycle as a delivery is not an
overrun: the read returns the old character and the new one is buffered.

### 8.5 Break detection

In asynchronous mode the receiver counts consecutive received frames whose data
bits, parity bit, and stop bit are all low. When two such frames accumulate,
break detect asserts. It clears when `rxd` samples high, and on reset. Break
detect is not cleared by a status read.

## 9. Shared `SYNDET` pin and modem control

- `syndet_oe` is asserted when the device is configured and either asynchronous
  mode is programmed or synchronous mode with internal detection is programmed.
  In synchronous mode with external detection the pin is an input and
  `syndet_oe` is low. Before the mode instruction is written, `syndet_oe` is
  low.
- `syndet_o` carries break detect in asynchronous mode and the sync-detect flag
  in synchronous mode.
- `rts_n` is the inverse of the command `RTS` bit; `dtr_n` is the inverse of the
  command `DTR` bit. Both are inactive high after reset.
- `cts_n` gates character launch. `dsr_n` has no effect on the datapath and is
  visible only in the status byte.

## 10. Ordering and edge cases

- Within one clock cycle, effects are applied in this order: CPU read side
  effects, transmitter, receiver, then CPU writes. A CPU write therefore wins
  any conflict with an internal update in the same cycle.
- A CPU data write in the same cycle as a transmit consume leaves the buffer
  full.
- A CPU data read in the same cycle as a receive delivery leaves the buffer full
  and does not set `OE`.
- `ER` in the same cycle as a receiver-set error flag clears the flag.
- `IR` overrides all other bits of its command word and all internal activity in
  that cycle.
- `txc_tick` and `rxc_tick` asserted in the same cycle advance both engines
  independently.
- Simultaneous read and write strobes decode as no bus cycle.

## 11. Timing requirements

- All inputs are sampled on the rising edge of `clk` and must be stable at that
  edge.
- `data_o` and `data_oe` are combinational functions of the bus strobes and the
  registered state, so read data is available in the same cycle the read cycle
  is decoded.
- A bus write must present `data_i` at the rising edge on which the write is
  decoded.
- `txc_tick` and `rxc_tick` must each be a single-cycle pulse. Two pulses in
  consecutive cycles are legal and represent a baud clock running at the core
  clock rate.

## 12. Scope exclusions

The following are outside the scope of this reconstruction:

- Pin-level and electrical behavior: NMOS levels, drive strength, setup and hold
  times, propagation delays, and the 28-pin package.
- Asynchronous operation of the historical part. The original device has no
  clock or reset pin for its register model and derives internal timing from
  `CLK` while sampling serial data on `TxC` and `RxC`; this core is fully
  synchronous to `clk`.
- The tristate CPU data bus and the bidirectional `SYNDET` pin, which are
  represented by separate input, output, and output-enable signals.
- Metastability and clock-domain crossing between the core clock and the
  baud-rate clocks. The environment is responsible for producing clean
  single-cycle tick enables.
- Differences between the original 8251 and the 8251A beyond the programming
  model. The behavior specified here follows the 8251A, which is fully
  double-buffered and adds break detection on the `SYNDET`/`BD` pin. The
  original 8251 has documented usage restrictions around command timing that are
  not modeled.
- Baud-rate generation and the RS-232 line interface, which are external.

## 13. References

- Intel 8251A programmable communication interface datasheet reproductions
  archived at [alldatasheet](https://www.alldatasheet.com/datasheet-pdf/pdf/66096/INTEL/8251A.html).
- Mode, command, and status bit assignments cross-checked against the
  [NJIT EE395 8251A programming notes](https://web.njit.edu/~gilhc/EE395/8251int.htm).
- Device summary and documentation history in the
  [Intel 8251 historical summary](https://en.wikipedia.org/wiki/Intel_8251).

Source material is summarized and rephrased for licensing compliance; no source
text is reproduced verbatim beyond device names, signal names, and field
mnemonics.
