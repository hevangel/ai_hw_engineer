# Intel 8279 final design report

## Implementation

The synthesizable `intel_8279` core implements the 8279 digital programming model: all eight command classes, eight/16-position display modes and RAM, one shared display address/AI register, left/right entry, nibble inhibit/blank, display clear, encoded/decoded scanning, two-key lockout, N-key rollover and special error, sensor matrix, strobed input, FIFO/status/IRQ, and programmable scan timing. The source behavior is described in the [specification](../spec/spec.md), with the [Intel data sheet](https://datasheets.pl/elementy_czynne/IC/8/8279.pdf) as the primary technical reference.

The core uses synchronous bus transactions and split data pins. It is a functional model of the digital device rather than a pin-timing or electrical clone. `SCAN_DIV=64` is the production scan setting. A second simulation verifies that the reset prescaler of 31 advances one display position after `31 × 64` clocks. Directed functional simulation uses `SCAN_DIV=1` to cover operations quickly.

## Verification

| Check | Result |
|---|---|
| Verilator RTL and two testbench lint with `-Wall` | PASS, zero warnings |
| Verible lint on authored RTL, benches, and formal sources | PASS, zero violations |
| Directed xezim functional simulation | PASS, 79 checks, zero failures |
| Default scan-timing xezim simulation | PASS, `31 × 64` clocks per digit |
| SymbiYosys depth-24 BMC | PASS |
| SymbiYosys ABC PDR unbounded proof | PASS |
| SymbiYosys reset-constrained cover | PASS, display clear reached at step 3 |
| Generic Yosys synthesis | PASS, zero structural problems, 3,343 generic cells |

The functional test checks display addressing, nibble inhibit and blank code, clear busy and write blocking, right entry, decoded scan, sensor IRQ/read modes, strobed capture, FIFO order/full/overrun/underrun, rollover, lockout, and special error. Formal safety checks reset state, legal FIFO/prescaler counts, bus output enable, IRQ derivation, and blanking during clear. Formal coverage checks that clear busy/blanking is reachable from reset. Neither safety proof nor a single cover proves full data-path equivalence; the directed simulation checks the data values at the external bus and display pins.

## Scope limits

- Analog contact bounce, metastability, and physical bus strobe setup/hold timing are outside the synchronous model.
- The active-low modifier inputs are encoded as asserted-high FIFO bits. The Intel data sheet identifies them as status bits but does not explicitly state code polarity; this assumption is called out in RTL and spec.
- No board-level or historical firmware run is included; integration depends on a host system and keyboard/display wiring.

Run the full toolchain with `sh design/intel_8279/scripts/run_all.sh` inside `ai-hw-engineer:latest`.
