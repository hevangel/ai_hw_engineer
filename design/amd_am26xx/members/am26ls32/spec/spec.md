# Am26LS32 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-40 to 4-44 (PDF pages 272-275): distinctive
characteristics, functional description, logic diagram (BLI-024) and
connection diagram (LIC-360) on page 4-40; electrical characteristics
on 4-41/4-42; switching characteristics on 4-43. The shared quad-driver/
receiver application note ("Use of the Am26LS29, 30, 31 and 32 quad
driver/receiver family in EIA RS-422 and 423 applications") spans pages
4-45 to 4-56 and documents the intended RS-422/RS-423 systems use.

## Part identity

Quad differential line receiver meeting RS-422 and RS-423 (Federal
Standards 1020 and 1030): four non-inverting differential receivers
with 3-state outputs (8 mA sink), a common enable pair, ±200 mV input
sensitivity over the ±7 V input voltage range, 30 mV input hysteresis,
6 kΩ minimum input impedance, 17 ns typical propagation delay, and the
documented fail-safe input-output relationship: "output always high
when inputs are open".

First introduced: **1977*** — the Am26LS31/LS32 pairing appears in the
[1977 AMD Linear and Interface Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1977_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-27/4-31 of that book, PDF pages 128/132); the 1979 book
reprints the part (pages 4-40..4-44). The earliest located dated
documentation is therefore the 1977 book; the bound is retained rather
than guessed (no month-level claim).

## Interface (16-pin package, pins per LIC-360)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `a_in_n_i` | INPUTS A −, pin 1 | in | Receiver A inverting input |
| `a_in_p_i` | INPUTS A +, pin 2 | in | Receiver A non-inverting input |
| `a_out_o` | OUTPUT A, pin 3 | out | Receiver A 3-state output |
| `en_n_i` | ENABLE, pin 4 | in | Enable, active low |
| `c_out_o` | OUTPUT C, pin 5 | out | Receiver C 3-state output |
| `c_in_p_i` | INPUTS C +, pin 6 | in | Receiver C non-inverting input |
| `c_in_n_i` | INPUTS C −, pin 7 | in | Receiver C inverting input |
| `d_in_p_i` | INPUTS D +, pin 10 | in | Receiver D non-inverting input |
| `d_in_n_i` | INPUTS D −, pin 9 | in | Receiver D inverting input |
| `d_out_o` | OUTPUT D, pin 11 | out | Receiver D 3-state output |
| `en2_i` | ENABLE(bar), pin 12 | in | Enable, active high |
| `b_out_o` | OUTPUT B, pin 13 | out | Receiver B 3-state output |
| `b_in_p_i` | INPUTS B +, pin 14 | in | Receiver B non-inverting input |
| `b_in_n_i` | INPUTS B −, pin 15 | in | Receiver B inverting input |

Unmodeled pins: VCC pin 16; GND pin 8.

## Boolean contract

Per receiver (non-inverting differential comparator with 3-state
output):

```
comp    = (IN+ > IN-)                    // comparator decision
enabled = !ENABLE || ENABLE(bar)         // pin 4 low or pin 12 high
OUT     = enabled ? comp : 'Z            // 3-state
```

The differential decision is modeled on binary line states; the
equal-inputs code stands for the open line, and the documented fail-
safe keeps the outputs HIGH there (`comp = (in_p >= in_n)` in the
binary model). All 2^10 input combinations are defined; the 3-state
output is the only stateful-looking element and is a pure function of
the enable pair.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — 200 mV
sensitivity over ±7 V, 30 mV hysteresis, 6 kΩ input impedance, 17 ns
typical delay, 3-state enable/disable times, 8 mA sink capability — is
documented in the datasheet and out of scope here.

## Assumptions

- ASSUMPTION: the equal-inputs binary code represents the open-line
  state and resolves to output HIGH per the documented fail-safe; the
  continuous comparator behavior (sensitivity window, hysteresis,
  common-mode range) is not modeled.
- ASSUMPTION: the two enables are OR-ed (enabled when pin 4 is low or
  pin 12 is high); both-disabled is the only high-impedance state.
