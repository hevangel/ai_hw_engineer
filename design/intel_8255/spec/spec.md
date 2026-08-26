# Specification: Intel 8255 Programmable Peripheral Interface

## 1. Overview

`intel_8255` is a synthesizable functional reconstruction of the Intel 8255A Programmable Peripheral Interface (PPI). It connects an 8-bit CPU bus to three 8-bit peripheral ports. Software selects simple, strobed, or bidirectional operation by writing the control address.

The historical part has no clock. This implementation samples bus transactions and external handshake transitions on `clk` so that it maps reliably to synchronous logic. It reproduces the digital programming model and handshake ordering, not original asynchronous pin timing.

## 2. Features

- 24 peripheral lines arranged as Ports A, B, and C.
- Four CPU addresses selected by `addr[1:0]`.
- Mode 0: latched outputs and direct buffered inputs.
- Mode 1: strobed input or output with buffer-full and interrupt handshaking.
- Mode 2: bidirectional strobed Port A with independent input and output paths.
- Group A comprises Port A and Port C upper; Group B comprises Port B and Port C lower.
- Port C Bit Set/Reset (BSR) commands.
- Mode-dependent hidden interrupt-enable controls programmed through BSR.
- Separate pin input, output, and output-enable vectors for synthesis-friendly bidirectional integration.
- Active-high reset matching the original device's RESET polarity.

## 3. Interfaces

### 3.1 Port list

| Port | Direction | Width | Description |
|---|---|---:|---|
| `clk` | input | 1 | Sampling clock for CPU and peripheral handshake events |
| `reset` | input | 1 | Active-high synchronous reset |
| `cs_n` | input | 1 | Active-low CPU chip select |
| `rd_n` | input | 1 | Active-low CPU read strobe |
| `wr_n` | input | 1 | Active-low CPU write strobe |
| `addr` | input | 2 | Register address corresponding to historical A1:A0 |
| `data_i` | input | 8 | CPU write data |
| `data_o` | output | 8 | CPU read data |
| `data_oe` | output | 1 | CPU read-data output enable |
| `port_a_i` | input | 8 | Sampled Port A pins |
| `port_a_o` | output | 8 | Port A drive value |
| `port_a_oe` | output | 8 | Per-bit Port A drive enable, active high |
| `port_b_i` | input | 8 | Sampled Port B pins |
| `port_b_o` | output | 8 | Port B drive value |
| `port_b_oe` | output | 8 | Per-bit Port B drive enable, active high |
| `port_c_i` | input | 8 | Sampled Port C pins, including handshake inputs |
| `port_c_o` | output | 8 | Port C drive/status value |
| `port_c_oe` | output | 8 | Per-bit Port C drive enable, active high |

At an integration boundary, each physical pin may be represented as `assign pad = oe ? o : 1'bz; assign i = pad;`.

### 3.2 CPU bus protocol

A transaction is accepted on a rising `clk` edge when `cs_n == 0` and exactly one of `rd_n` or `wr_n` is low.

- Write: `cs_n == 0`, `wr_n == 0`, `rd_n == 1`.
- Read: `cs_n == 0`, `rd_n == 0`, `wr_n == 1`.
- Idle or deselected: no state change.
- Both strobes low: invalid; no transaction is accepted and `data_oe` remains low.

Read data is combinational while a valid read is asserted. Any read side effect, such as clearing an input-buffer-full flag, occurs on the accepting rising edge. The control address is write-only and does not enable `data_o`.

## 4. Register map

| `addr` | Register | CPU read | CPU write |
|---:|---|---|---|
| `2'b00` | Port A | Current input latch/pins or output latch, by mode | Port A output latch when output-capable |
| `2'b01` | Port B | Current input latch/pins or output latch, by mode | Port B output latch when output-capable |
| `2'b10` | Port C | Mixed GPIO, handshake-input, and status value | Port C output latch bits not reserved for handshake |
| `2'b11` | Control | Unsupported; bus remains undriven | I/O mode-set word or BSR command |

Writes to input-only data ports are ignored. A Port C data write updates the complete Port C output latch; bits currently assigned as handshake signals remain internally stored but are masked at the pins.

## 5. Control words

### 5.1 I/O mode-set word (`data_i[7] == 1`)

| Bit | Meaning | Encoding |
|---:|---|---|
| 7 | Mode-set select | `1` |
| 6:5 | Group A mode | `00`: Mode 0, `01`: Mode 1, `1x`: Mode 2 |
| 4 | Port A direction | `1`: input, `0`: output; ignored in Mode 2 |
| 3 | Port C upper direction | `1`: input, `0`: output where not reserved |
| 2 | Group B mode | `0`: Mode 0, `1`: Mode 1 |
| 1 | Port B direction | `1`: input, `0`: output |
| 0 | Port C lower direction | `1`: input, `0`: output where not reserved |

An accepted mode-set write stores the word and clears all three output latches, both input latches, `IBF_A`, `IBF_B`, both active-low OBF states to inactive high, and all interrupt-enable controls. The current Port C input sample becomes the edge-detection baseline, preventing a configuration write from creating a false handshake edge.

Reset is equivalent to a fresh all-input Mode 0 state (`8'h9b`) and clears all latches and handshake state.

### 5.2 Bit Set/Reset word (`data_i[7] == 0`)

| Bits | Meaning |
|---|---|
| 6:4 | Don't care |
| 3:1 | Port C bit number, `000` for PC0 through `111` for PC7 |
| 0 | `1`: set selected latch/INTE; `0`: reset it |

Every BSR command updates the selected Port C output-latch bit without changing the current I/O mode. For mode-assigned handshake pins, the same command also controls hidden interrupt enables:

| Active mode | BSR bit | Hidden control |
|---|---:|---|
| Group A Mode 1 input | PC4 | `INTE_A_input` |
| Group A Mode 1 output | PC6 | `INTE_A_output` |
| Group A Mode 2 | PC4 | `INTE_A_input` |
| Group A Mode 2 | PC6 | `INTE_A_output` |
| Group B Mode 1, either direction | PC2 | `INTE_B` |

## 6. Functional modes

### 6.1 Mode 0: simple I/O

- Port A and Port B directions are independently programmable in 8-bit units.
- Port C upper and lower directions are independently programmable in 4-bit units.
- Output writes are latched.
- Reads of output-configured pins return the output latch.
- Reads of input-configured pins return the live input vector.
- No handshake or interrupt behavior is active.

### 6.2 Mode 1: strobed I/O

Mode 1 uses one 8-bit data port and three Port C lines per group. Remaining Group A Port C lines retain the direction selected by bit 3.

#### Group A input

| Pin | Function | Direction |
|---|---|---|
| PC3 | `INTR_A` | output |
| PC4 | `STB_A_n` | input |
| PC5 | `IBF_A` | output |
| PC7:PC6 | ordinary Port C | programmed by D3 |

A sampled high-to-low transition on PC4 captures `port_a_i` into the Port A input latch and sets `IBF_A`. `INTR_A` is high when PC4 has returned high, `IBF_A` is set, and `INTE_A_input` is set. An accepted Port A CPU read returns the input latch and clears `IBF_A`, which deasserts the interrupt.

#### Group A output

| Pin | Function | Direction |
|---|---|---|
| PC3 | `INTR_A` | output |
| PC6 | `ACK_A_n` | input |
| PC7 | `OBF_A_n` | output |
| PC5:PC4 | ordinary Port C | programmed by D3 |

An accepted Port A CPU write stores data and asserts `OBF_A_n` low. A sampled high-to-low transition on PC6 acknowledges the byte and returns `OBF_A_n` high. `INTR_A` is high when PC6 is high, `OBF_A_n` is high, and `INTE_A_output` is set. A later Port A write deasserts the interrupt by driving `OBF_A_n` low.

#### Group B input

| Pin | Function | Direction |
|---|---|---|
| PC0 | `INTR_B` | output |
| PC1 | `IBF_B` | output |
| PC2 | `STB_B_n` | input |

A PC2 high-to-low transition captures `port_b_i` and sets `IBF_B`. `INTR_B` is high when PC2 is high, `IBF_B` and `INTE_B` are set. A Port B read returns the latch and clears `IBF_B`.

#### Group B output

| Pin | Function | Direction |
|---|---|---|
| PC0 | `INTR_B` | output |
| PC1 | `OBF_B_n` | output |
| PC2 | `ACK_B_n` | input |

A Port B write asserts `OBF_B_n` low. A PC2 high-to-low transition acknowledges the byte and returns `OBF_B_n` high. `INTR_B` is high when PC2 and `OBF_B_n` are high and `INTE_B` is set.

### 6.3 Mode 2: strobed bidirectional Port A

Group A Mode 2 reserves PC7:PC3 and gives Port A independent latched input and output paths.

| Pin | Function | Direction |
|---|---|---|
| PC3 | `INTR_A` | output |
| PC4 | `STB_A_n` | input |
| PC5 | `IBF_A` | output |
| PC6 | `ACK_A_n` | input |
| PC7 | `OBF_A_n` | output |

Input sequencing matches Mode 1 input; output sequencing matches Mode 1 output. `INTR_A` is the OR of the qualified input and output requests. A CPU read clears only `IBF_A`; a CPU write starts only the output handshake. `OBF_A_n` low advertises a pending output byte, but Port A remains released while `ACK_A_n` is high. The peripheral asserts PC6 low to acknowledge the pending byte; that low level enables Port A to drive the output latch. When PC6 returns high, Port A releases again. Group B remains independently configurable in Mode 0 or Mode 1 using PC2:PC0.

## 7. Port C read and drive behavior

The implementation first forms a Mode 0-style value from the Port C input pins or output latch according to D3 and D0. It then overrides reserved handshake bits with their status outputs or sampled input-pin values. Output enables are similarly overridden: status pins drive and handshake inputs release.

This means a Port C read always exposes the externally meaningful state: GPIO values on unreserved pins, `STB_n`/`ACK_n` levels on handshake inputs, and `INTR`/`IBF`/`OBF_n` values on status outputs.

## 8. Ordering and edge cases

Within one sampled cycle:

1. reset has highest priority;
2. an I/O mode-set write has next priority and suppresses handshake processing;
3. otherwise handshake edges are processed, followed by accepted data/BSR bus operations;
4. a CPU operation to the same channel wins the resulting status conflict: read clears a just-filled `IBF`, and write asserts `OBF_n` after a simultaneous acknowledge.

Input data may be overwritten if a second strobe arrives before the CPU reads the prior byte, matching the absence of a FIFO. Unsupported reads and invalid simultaneous read/write strobes have no side effects.

## 9. Timing requirements

- All state changes occur on rising `clk` edges.
- CPU control, address, and write data must satisfy the target technology's setup/hold requirements around that edge.
- A high-to-low handshake transition must be represented by at least one sampled high cycle followed by one sampled low cycle.
- No internal synchronizers are provided. System integration must synchronize asynchronous peripheral inputs or clock slowly enough to meet sampling requirements.
- Read data, output data, and output enables are combinational functions of registered state and current bus/pin inputs.

## 10. Scope exclusions

The following original-device characteristics are outside scope:

- NMOS/CMOS process behavior, TTL voltage levels, drive current, fan-out, and leakage;
- package pin numbering and 40-pin/44-pin electrical compatibility;
- original asynchronous pulse-width, propagation-delay, and recovery specifications;
- metastability protection and clock-domain crossing circuitry;
- behavior of undocumented or electrically illegal bus combinations beyond the deterministic rules above.

## 11. References

- [Intel 8255A datasheet reproduction](https://www.cambridge.org/core/books/ibmpc-in-the-laboratory/8255-programmable-peripheral-interface-data-sheets/1B5F5ABF95580D00D463BA07BF9A892A)
- [Archived Intel 8255A datasheet PDF](https://4donline.ihs.com/images/VipMasterIC/IC/RSEL/RSEL-S-A0000095683/RSEL-S-A0000095683-1.pdf?hkey=6D3A4C79FDBF58556ACFDE234799DDF0)
- [Intel 8255A applications note catalog entry](https://www.computerhistory.org/collections/catalog/102671978)
- [8255 historical and programming summary](https://en.wikipedia.org/wiki/Intel_8255)
- [NPTEL Mode 1 output lecture](https://archive.nptel.ac.in/content/storage2/courses/108107029/module9/lecture52.pdf)
- [NPTEL Mode 2 lecture](https://archive.nptel.ac.in/content/storage2/courses/108107029/module9/lecture53.pdf)

Source content is summarized and rephrased for licensing compliance.
