# Am2614 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-45 to 4-50 (PDF pages 378-383): functional
description, logic diagrams and connection diagram on 4-45; DC
characteristics and switching on 4-46/4-47; typical characteristics and
definition of terms on 4-47/4-48. The identical part is reprinted in the
[1979 Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-67 to 4-71, PDF pages 299-302); both printings agree on the
logic and pinout. The same 1974 sheet also documents the Am9614 dual
differential driver; this specification reconstructs the Am2614 member
only.

## Part identity

Quad inverting line driver "with two separate inputs and one common-
strobe input for each pair of drivers", DTL/TTL compatible, single 5 V
supply, active pull-up outputs with short-circuit protection, capable of
driving 50 Ω terminated transmission lines; used for single-ended
transmission-line driving, memory decoding, buffering, clock driving and
general logic.

First introduced: **1974*** — earliest located dated AMD documentation
is the 1974 Data Book itself; the bound is retained rather than guessed.

## Interface (16-pin package, pins per the connection diagram)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `strobe_a_i` | STROBE A, pin 1 | in | Common strobe of pair A |
| `in_a1a_i` | INPUT A1, pin 2 | in | Driver A1 data input |
| `in_a1b_i` | INPUT A1, pin 3 | in | Driver A1 data input |
| `out_a1_o` | OUTPUT A1, pin 4 | out | Driver A1 output (inverting) |
| `in_a2a_i` | INPUT A2, pin 5 | in | Driver A2 data input |
| `in_a2b_i` | INPUT A2, pin 6 | in | Driver A2 data input |
| `out_a2_o` | OUTPUT A2, pin 7 | out | Driver A2 output (inverting) |
| `strobe_b_i` | STROBE B, pin 15 | in | Common strobe of pair B |
| `in_b1a_i` | INPUT B1, pin 14 | in | Driver B1 data input |
| `in_b1b_i` | INPUT B1, pin 13 | in | Driver B1 data input |
| `out_b1_o` | OUTPUT B1, pin 12 | out | Driver B1 output (inverting) |
| `in_b2a_i` | INPUT B2, pin 11 | in | Driver B2 data input |
| `in_b2b_i` | INPUT B2, pin 10 | in | Driver B2 data input |
| `out_b2_o` | OUTPUT B2, pin 9 | out | Driver B2 output (inverting) |

Unmodeled pins: VCC pin 16; GND pin 8.

## Boolean contract

Per the logic diagram, each driver is a 3-input inverting NAND whose
inputs are the two data pins and the pair strobe:

```
out_a1 = !(in_a1a && in_a1b && strobe_a)
out_a2 = !(in_a2a && in_a2b && strobe_a)
out_b1 = !(in_b1a && in_b1b && strobe_b)
out_b2 = !(in_b2a && in_b2b && strobe_b)
```

A strobe LOW idles the pair's outputs HIGH (the line de-asserted); with
the strobe HIGH each output follows the NAND of its two data inputs.
There is no state, no clock, no undocumented encoding: all 2^10 input
combinations are defined combinationally.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. The electrical contract —
active pull-up, short-circuit protection, 50 Ω terminated-line drive,
propagation delays (t_pd+ 8 ns typ / 12 ns max, t_pd- 7 ns typ / 10 ns
max at 25 °C), input clamp diodes, MIL/commercial VIL/VIH windows — is
documented in the datasheet and out of scope here.

## Assumptions

None at the digital level: the logic diagram and connection diagram fix
the function and pin map completely, and both data-book printings agree.
