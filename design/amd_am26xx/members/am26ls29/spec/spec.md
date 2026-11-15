# Am26LS29 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-26 to 4-29 (PDF pages 258-261): distinctive
characteristics, functional description, logic diagram (BLI-001) and
connection diagram (BLI-004) on page 4-26; DC characteristics on 4-27;
switching waveforms (rise-time control, three-state delays) on 4-28.
The part first appears in the
[1978 AMD Schottky and Low-Power Schottky Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1978_AMD_Schottky_and_Low-Power_Schottky_Data_Book_including_Digital_Signal_Processing_Handbook_Second_Edition_197807.pdf)
(PDF pages 307-309).

## Part identity

Quad three-state single-ended line driver meeting EIA RS-423 and Federal
Standard 1030: four buffered non-inverting outputs with high source and
sink current, output short-circuit protection, per-output slew-rate
control (external capacitor per driver for near-end crosstalk
suppression), three-state outputs for bus-oriented systems whose
hi-impedance state does not clamp the line, and low-current PNP inputs
compatible with TTL, MOS and CMOS.

First introduced: **1978*** — earliest located dated AMD documentation
is the July 1978 Schottky and Low-Power Schottky Data Book; the bound
is retained rather than guessed (no month-level claim).

## Interface (16-pin package, pins per BLI-004)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `in_a_i` | INPUT A, pin 2 | in | Driver A data input |
| `out_a_o` | OUTPUT A, pin 15 | out | Driver A 3-state output |
| `in_b_i` | INPUT B, pin 3 | in | Driver B data input |
| `out_b_o` | OUTPUT B, pin 14 | out | Driver B 3-state output |
| `en_n_i` | ENABLE, pin 4 | in | Enable, active low (all four drivers) |
| `in_c_i` | INPUT C, pin 6 | in | Driver C data input |
| `out_c_o` | OUTPUT C, pin 11 | out | Driver C 3-state output |
| `in_d_i` | INPUT D, pin 7 | in | Driver D data input |
| `out_d_o` | OUTPUT D, pin 10 | out | Driver D 3-state output |
| `sr_a_i` | SLEW RATE CONTROL A, pin 16 | in | Analog-only pin (see below) |
| `sr_b_i` | SLEW RATE CONTROL B, pin 13 | in | Analog-only pin |
| `sr_c_i` | SLEW RATE CONTROL C, pin 12 | in | Analog-only pin |
| `sr_d_i` | SLEW RATE CONTROL D, pin 9 | in | Analog-only pin |

Unmodeled pins: VCC pin 1; GND pin 5; VEE pin 8.

## Boolean contract

Per the logic diagram (four non-inverting 3-state buffers gated by one
active-low enable):

```
enabled = !ENABLE                 // pin 4 low
OUT     = enabled ? IN : 'Z       // per driver
```

All input combinations are defined; the 3-state output is a pure
function of the enable.

## Slew-rate-control pins

The four SLEW RATE CONTROL pins connect an external capacitor per
driver to shape the output rise/fall time (tr 3.0 µs with 50 pF to
120-300 ns with 0 pF, and the SRC coefficient figure). They are analog
nodes with no boolean effect. The reconstruction exposes them as
documented, explicitly unused inputs (referenced into an `_unused_sr`
term) so the port map matches the physical pin map and lint stays
clean.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — RS-423
output swing (±4 V minimum loaded), slew figures, three-state
enable/disable times, 50 Ω line drive, short-circuit current, the
not-clamping hi-impedance state — is documented in the datasheet and
out of scope here.

## Assumptions

- ASSUMPTION: the slew-rate-control pins have no boolean effect and
  are exposed as unused inputs rather than omitted, to preserve the
  physical pin map.
- ASSUMPTION: the enable is common to all four drivers and active low
  (logic diagram BLI-001 gate polarity; the three-state timing figures
  measure enable-LOW transitions).
