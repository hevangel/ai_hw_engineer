# Am26LS31 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-36 to 4-39 (PDF pages 268-270): distinctive
characteristics, functional description, logic diagram (LIC-352) and
connection diagram (LIC-353) on page 4-36; electrical characteristics
and switching (enable/disable times) on page 4-37; equivalent circuit
and typical application on page 4-38. The shared quad-family
application note (pages 4-45 to 4-56) documents the RS-422 systems use.
The part first appears in the
[1977 AMD Linear and Interface Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1977_AMD_Linear_and_Interface_Data_Book.pdf)
(PDF pages 128-131).

## Part identity

Quad high-speed differential line driver meeting EIA RS-422 and Federal
Standard 1020: four drivers with complementary 3-state outputs, an
OR-ed complementary enable pair common to all four, 2.0 ns typical
output skew, 12 ns typical input-to-output delay, single +5 V supply,
outputs that do not load the line when VCC = 0, and short-circuit
protection.

First introduced: **1977*** — earliest located dated AMD documentation
is the 1977 Linear and Interface Data Book; the bound is retained
rather than guessed (no month-level claim).

## Interface (16-pin package, pins per LIC-353)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `in_a_i` | INPUT A, pin 1 | in | Driver A data input |
| `y_a_o` | OUTPUT A+, pin 2 | out | Driver A true 3-state output |
| `z_a_o` | OUTPUT A−, pin 3 | out | Driver A complement 3-state output |
| `en_n_i` | ENABLE, pin 4 | in | Enable, active low |
| `y_b_o` | OUTPUT B+, pin 5 | out | Driver B true 3-state output |
| `z_b_o` | OUTPUT B−, pin 6 | out | Driver B complement 3-state output |
| `in_b_i` | INPUT B, pin 7 | in | Driver B data input |
| `in_c_i` | INPUT C, pin 9 | in | Driver C data input |
| `y_c_o` | OUTPUT C+, pin 10 | out | Driver C true 3-state output |
| `z_c_o` | OUTPUT C−, pin 11 | out | Driver C complement 3-state output |
| `en2_i` | ENABLE(bar), pin 12 | in | Enable, active high |
| `z_d_o` | OUTPUT D−, pin 13 | out | Driver D complement 3-state output |
| `y_d_o` | OUTPUT D+, pin 14 | out | Driver D true 3-state output |
| `in_d_i` | INPUT D, pin 15 | in | Driver D data input |

Unmodeled pins: VCC pin 16; GND pin 8.

## Boolean contract

Per the logic diagram (each driver a 3-state buffer pair, enables
OR-ed):

```
enabled = !ENABLE || ENABLE(bar)     // pin 4 low or pin 12 high
Y       = enabled ? IN  : 'Z
Z       = enabled ? !IN : 'Z
```

All 2^6 input combinations are defined; the 3-state output pair is a
pure function of the enable pair.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — RS-422
conformance, 2.0 ns output skew, 12 ns typical delay, 100 Ω
terminated-line drive, short-circuit protection, enable/disable times —
is documented in the datasheet and out of scope here.

## Assumptions

- ASSUMPTION: the two enables are OR-ed (enabled when pin 4 is low or
  pin 12 is high); both-released is the only high-impedance state.
