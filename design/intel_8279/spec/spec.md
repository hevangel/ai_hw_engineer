# Intel 8279 keyboard/display interface specification

## Source and scope

The digital command and data behavior follows Intel's [8279/8279-5 data sheet](https://datasheets.pl/elementy_czynne/IC/8/8279.pdf), especially the command descriptions and interface considerations on pages 3–7. This implementation is a synchronous, synthesizable functional core. It separates the bidirectional data bus into `data_i`, `data_o`, and `data_oe`; an external wrapper must supply bus direction and electrical timing. `rst_n` is active low and sampled on `clk`.

## Interface and timing

| Signal | Purpose |
|---|---|
| `cs_n`, `rd_n`, `wr_n`, `a0` | Active-low chip select and bus strobes; `a0=1` selects command/status |
| `data_i`, `data_o`, `data_oe` | Split eight-bit bidirectional bus |
| `sl[3:0]`, `rl[7:0]` | Encoded or active-low one-of-four scan and active-low returns |
| `shift`, `cntl_stb` | Keyboard modifiers; `cntl_stb` is the rising-edge strobe in strobed mode |
| `out_a`, `out_b`, `bd_n` | Display nibbles and active-low display blank |
| `irq` | Active-high FIFO or sensor interrupt |

The clock command programs a divisor of 2–31 (reset value 31); values 0 and 1 are clamped to 2. By default, one display scan position lasts 64 prescaled clock ticks (`SCAN_DIV=64`). Thus an eight-position scan lasts 512 prescaled ticks, matching the data sheet's nominal 5.1 ms at a 100 kHz internal clock. `SCAN_DIV=1` is used only for accelerated functional simulation and formal reachability. A scanned keyboard key is accepted after it remains closed across two complete row revisits. CPU writes and read side effects occur on `clk` edges in this model; the physical chip latches on bus-strobe edges.

## Commands

The CPU writes commands with `a0=1`. Bits `D7:D5` select:

| Code | Command | Effect |
|---|---|---|
| `000` | Mode set | `DD` chooses 8/16 and left/right entry; `KKK` chooses encoded/decoded lockout, rollover, sensor, or strobed input |
| `001` | Program clock | `PPPPP` selects the prescaler |
| `010` | Read FIFO/sensor | Selects read source; `AI` and row apply to sensor reads |
| `011` | Read display | Selects display read source and sets the shared display address/AI register |
| `100` | Write display | Sets the same address/AI register; leaves read source unchanged |
| `101` | Write inhibit/blank | `IW_A`, `IW_B`, `BL_A`, `BL_B` control nibbles independently |
| `110` | Clear | `CD` clears display to 00, 20, or FF; `CF` empties FIFO and error/IRQ status; `CA` does both and resynchronizes scan |
| `111` | End interrupt/error | Clears sensor IRQ; `E` selects rollover special-error mode |

Data writes (`a0=0`) target display RAM. Read/display commands share one address and auto-increment bit. Reads from FIFO pop one entry regardless of `AI`; sensor reads advance only with `AI`. Decoded scanning exposes four display positions even when `DD` requests eight or sixteen. Right-entry output rotates the logical display origin so the newest position appears at the right edge. The display RAM remains directly addressable.

## Input behavior

Scanned keyboard returns are active low. A confirmed key enters an eight-entry FIFO as `{CNTL, SHIFT, scan[2:0], return[2:0]}`. **ASSUMPTION:** the two modifier code bits are asserted high when their active-low input pins are low; the data sheet calls them status bits but does not explicitly state their encoded polarity. Normal rollover admits distinct held keys in scan order; two-key lockout admits a key only when it is alone. Special error mode blocks further FIFO writes when overlapping pending closures are detected and raises `S/E` and IRQ. A full FIFO sets overrun; an empty read sets underrun. The status byte is `{DU, S/E, O, U, F, N[2:0]}`; `N=0` when full.

In sensor mode, each scanned row records the raw return byte. A change raises IRQ and freezes further sensor RAM updates until an end-interrupt command or a non-auto-increment sensor read. Strobed mode captures the return byte on a sampled rising edge of `cntl_stb`.

## Functional model boundaries

The core does not model analog switch bounce, metastability, propagation delay, or bidirectional bus electrical drive. The display blank output is driven low during a display clear; individual nibble blanking uses the clear code. A host with physical 8279 timing requirements needs an external bus adapter and board-level timing validation.
