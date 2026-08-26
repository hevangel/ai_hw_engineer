# Intel 8253/8254 Programmable Interval Timer Specification

## 1. Scope

This design implements the digital programming model of the Intel 8253 and 8254 programmable interval timers in one synthesizable SystemVerilog module. The elaboration parameter `IS_8254` selects the variant:

- `IS_8254 = 1'b0`: Intel 8253 behavior. Read-back commands are ignored and one LSB/MSB phase bit is shared by reads and writes for each counter.
- `IS_8254 = 1'b1`: Intel 8254 behavior. Read-back count/status commands are supported and each counter has independent read and write LSB/MSB phase bits.

Both variants provide three independent 16-bit counters, six operating modes, binary or four-decade BCD counting, count latching, and the original four-address CPU programming model.

## 2. Synthesizable timing abstraction

The historical parts contain three independent asynchronous counter clock domains and no device-wide clock or reset pin. This implementation adds one integration clock and a deterministic reset:

- All CPU transactions and external inputs are sampled on rising edges of `clk`.
- A counter clock event is recognized when `counter_clk_i[n]` was high at the previous `clk` edge and is low at the current edge. Integrators must therefore present each high and low level for at least one `clk` period.
- A GATE trigger is recognized when `gate_i[n]` was low at the previous `clk` edge and is high at the current edge.
- `rst_n` is an active-low synchronous integration reset. It is not a historical package pin.
- CPU read data and `data_oe` are combinational from the sampled state and active-low bus strobes.

The core does not contain clock-domain synchronizers. External asynchronous signals must be synchronized by the integration layer. Electrical levels, metastability, package timing, and original maximum clock-frequency grades are outside scope.

## 3. Interface

| Port | Direction | Width | Description |
|---|---|---:|---|
| `clk` | input | 1 | Integration clock |
| `rst_n` | input | 1 | Active-low synchronous reset |
| `cs_n` | input | 1 | Active-low chip select |
| `rd_n` | input | 1 | Active-low CPU read strobe |
| `wr_n` | input | 1 | Active-low CPU write strobe |
| `addr` | input | 2 | CPU register address |
| `data_i` | input | 8 | CPU write data |
| `data_o` | output | 8 | CPU read data |
| `data_oe` | output | 1 | CPU data-bus output enable |
| `counter_clk_i` | input | 3 | Sampled counter clocks, one bit per counter |
| `gate_i` | input | 3 | Sampled GATE inputs, one bit per counter |
| `out_o` | output | 3 | Counter OUT signals |

A legal read is `!cs_n && !rd_n && wr_n`. A legal write is `!cs_n && rd_n && !wr_n`. Simultaneously active `rd_n` and `wr_n` is invalid: it neither drives the read bus nor changes programmed state.

## 4. Address map

| `addr` | Read | Write |
|---:|---|---|
| `2'b00` | Counter 0 data/status | Counter 0 count byte |
| `2'b01` | Counter 1 data/status | Counter 1 count byte |
| `2'b10` | Counter 2 data/status | Counter 2 count byte |
| `2'b11` | Undriven | Control word or 8254 read-back command |

`data_oe` is asserted only for a legal read of addresses 0 through 2.

## 5. Control words

For `data_i[7:6] != 2'b11`, a control write programs one counter.

| Bits | Meaning |
|---|---|
| `[7:6]` | Counter select: 0, 1, or 2 |
| `[5:4]` | Read/write format: `00` latch current count, `01` LSB, `10` MSB, `11` LSB then MSB |
| `[3:1]` | Mode: 0 through 5; encodings 6 and 7 alias modes 2 and 3 |
| `[0]` | `0` binary, `1` packed four-decade BCD |

A `RW=00` command latches the selected counter without changing mode, format, BCD setting, OUT, or counting. A second count-latch command does not overwrite an unread count latch.

A mode-programming control word:

- stores the read/write format, raw mode bits, and BCD selection;
- resets the selected counter's byte phases and unread latches;
- marks the count null until a complete count is transferred into the counting element;
- sets OUT low for Mode 0 and high for Modes 1 through 5;
- stops the selected counter until a complete count is written and the mode's start condition occurs.

## 6. Count programming and reading

### 6.1 Count values

A binary count of `16'h0000` represents 65,536. A BCD count of `16'h0000` represents 10,000. Packed BCD digits must each be 0 through 9. BCD writes containing non-decimal nibbles are outside the specified input domain.

Modes 2 and 3 require programmed counts of at least 2. Other values have deterministic RTL behavior but are outside the compatible programming domain.

### 6.2 Write sequencing

- LSB-only stores `{8'h00, data_i}` and completes the count.
- MSB-only stores `{data_i, 8'h00}` and completes the count.
- LSB/MSB stores the first byte as the low byte and completes the count on the second byte.
- Completing a count write sets the null-count indication until the counting element is loaded.
- In Mode 0, the first byte of an LSB/MSB rewrite stops the current count.
- Modes 0, 2, 3, and 4 transfer a completed count on the next sampled falling counter-clock event. Modes 1 and 5 arm the count and transfer it on the sampled falling counter-clock event associated with a GATE trigger.

For the 8254, read and write byte phases are independent. For the 8253, any LSB/MSB data access toggles the one shared phase for that counter; an intervening read can therefore redirect the next write, and vice versa.

### 6.3 Reads and latches

A direct read returns the current counting element according to the programmed format. A latched count has priority over the live value and remains stable until all bytes required by the programmed format are consumed. LSB/MSB reads return low byte first, then high byte.

For the 8254, a latched status byte has priority over a latched or live count. Reading status clears only the status latch and does not advance the count byte phase.

## 7. 8254 read-back command

A control write with `data_i[7:6] == 2'b11` is a read-back command only when `IS_8254=1`. The 8253 ignores it without changing any counter.

| Bit | Meaning |
|---|---|
| `[5]` | Active-low count-latch request |
| `[4]` | Active-low status-latch request |
| `[3]` | Active-low Counter 2 select |
| `[2]` | Active-low Counter 1 select |
| `[1]` | Active-low Counter 0 select |
| `[0]` | Reserved; ignored |

Each selected counter independently latches the requested information. An existing unread count or status latch is not overwritten.

Status byte format:

| Bit | Meaning |
|---:|---|
| 7 | Current OUT value |
| 6 | Null count: 1 until a completed programmed count is transferred to the counting element |
| 5:4 | Programmed read/write format |
| 3:1 | Raw programmed mode bits |
| 0 | BCD selection |

## 8. GATE and operating modes

All counter evolution below occurs on sampled falling counter-clock events unless an immediate sampled GATE effect is stated.

### 8.1 Mode 0 — interrupt on terminal count

Programming the mode drives OUT low. A completed count is loaded on the next counter-clock event. GATE high enables decrementing and GATE low pauses it. When a count of 1 receives an enabled event, the counter becomes 0 and OUT goes high. OUT remains high through subsequent wraparound counting until reprogrammed.

### 8.2 Mode 1 — hardware-retriggerable one-shot

Programming drives OUT high and a completed count arms the counter. A sampled GATE rising edge causes the next coincident or later counter-clock event to reload the programmed count and drive OUT low. GATE level after the trigger does not pause counting. Terminal count drives OUT high. Another GATE rising edge retriggers and reloads the one-shot, including while OUT is low.

### 8.3 Mode 2 — rate generator

Programming drives OUT high. With GATE high, the next counter-clock event loads the completed count. The counter decrements once per event. Transition from 2 to 1 drives OUT low; the following event reloads the programmed count and drives OUT high, producing a one-clock low pulse every N input clocks. Sampled GATE low forces OUT high and stops the sequence. A later sampled GATE rising edge restarts from the programmed count on the next coincident or later counter-clock event.

### 8.4 Mode 3 — square-wave generator

Programming drives OUT high. GATE start/stop behavior matches Mode 2. For even N, OUT is high for N/2 counter clocks and low for N/2. For odd N, OUT is high for `(N+1)/2` clocks and low for `(N-1)/2`. The internal count image follows the historical decrement-by-two algorithm: for odd counts, the first high-phase decrement is one and the first low-phase decrement is three. Sampled GATE low forces OUT high and resets the running phase.

### 8.5 Mode 4 — software-triggered strobe

Programming and count loading leave OUT high. GATE high enables decrementing and GATE low pauses it. Terminal count drives OUT low for one counter-clock interval; the next counter-clock event returns OUT high and stops the one-shot until another count is written.

### 8.6 Mode 5 — hardware-triggered strobe

Programming and count writing leave OUT high and arm the counter. A sampled GATE rising edge reloads on the next coincident or later counter-clock event. GATE level does not pause the active count. Terminal count drives OUT low for one counter-clock interval, then OUT returns high. A new GATE rising edge retriggers the sequence.

## 9. Event priority

At each integration-clock edge, priority is:

1. `!rst_n` resets all state.
2. A selected counter's mode/control command reprograms that counter.
3. A selected counter's count-data write updates that counter's programming state.
4. GATE effects and counter-clock events update all counters not superseded by steps 2 or 3.
5. A legal read consumes a selected status/count latch or advances its byte phase after presenting the pre-edge read value.

A CPU access to one counter does not prevent the other counters from evolving. A GATE rising edge sampled with a falling counter clock may trigger/restart on that same integration edge.

## 10. Reset

On synchronous reset, all counters enter a deterministic integration state: OUT high, Mode 0 metadata, binary LSB/MSB format, null count set, no active count, no pending trigger, and no unread latches. Counter-clock and GATE history are initialized from their current input levels to avoid synthetic edges when reset is released.

## 11. Sources and compatibility boundary

Behavior is based on Intel's 8253 description in the September 1975 *8080 Microcomputer Systems User's Manual*, Intel 8254/82C54 datasheet material, and Intel's continuing 8254-compatible chipset timer documentation. Historical context and links are collected in the design [README](../README.md).

This is a cycle-defined digital reconstruction, not a pin-, electrical-, or propagation-delay-compatible replacement. Source material is summarized and rephrased for licensing compliance.
