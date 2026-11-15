# Am26LS33 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-40 to 4-44 (PDF pages 272-275): the shared Am26LS32 ·
Am26LS33 sheet — distinctive characteristics, functional description,
logic diagram (BLI-024) and connection diagram (LIC-360) on page 4-40;
electrical characteristics on 4-41/4-42; switching on 4-43. The
Am26LS33's distinct electrical contract (500 mV sensitivity over ±15 V
input range) is stated in the shared distinctive characteristics and
the electrical tables.

## Part identity

Quad differential line receiver sharing the Am26LS32's logic diagram,
pin map, 3-state outputs, OR-ed complementary enable pair and fail-safe
relationship ("output always high when inputs are open"), but with the
wider-range electrical envelope: ±500 mV input sensitivity over the
±15 V input voltage range (the LS32 is ±200 mV over ±7 V).

First introduced: **1977*** — the Am26LS33 appears in the
[1977 AMD Linear and Interface Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1977_AMD_Linear_and_Interface_Data_Book.pdf)
alongside the LS32; the 1979 book reprints it. The bound is retained
rather than guessed (no month-level claim).

## Interface (16-pin package, pins per LIC-360 — identical to the Am26LS32)

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

Identical to the [Am26LS32](../am26ls32/spec/spec.md) (shared logic
diagram BLI-024):

```
comp    = (IN+ > IN-)
enabled = !ENABLE || ENABLE(bar)
OUT     = enabled ? comp : 'Z
```

with the fail-safe tie resolution (`comp = (in_p >= in_n)` in the
binary model, outputs HIGH on open inputs). All 2^10 input combinations
are defined.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — ±500 mV
sensitivity over ±15 V (the LS33's distinguishing envelope versus the
LS32's ±200 mV over ±7 V), hysteresis, 6 kΩ input impedance, delays,
3-state drive — is documented in the datasheet and out of scope here.

## Assumptions

- ASSUMPTION: the digital contract equals the Am26LS32's, per the
  shared logic diagram and functional description on the same datasheet
  page; the sensitivity-range difference is electrical and is
  documented here without digital consequence.
- ASSUMPTION: the equal-inputs binary code represents the open-line
  state and resolves to output HIGH per the documented fail-safe.
