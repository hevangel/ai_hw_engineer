# Am2617 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-82 to 4-85 (PDF pages 314-317): functional description,
logic symbol (LIC-417), circuit diagram (LIC-418) and connection
diagram (LIC-419) on page 4-82; electrical characteristics on 4-83/
4-84. RS-232C conformance ("Compatible with EIA specification RS-232C",
"Input signal range ±30 volts") is stated on page 4-82.

## Part identity

Quad line receiver for EIA RS-232C interconnection: four single-ended
receivers with guaranteed input thresholds over the full military
temperature range, built-in hysteresis for AC-noise immunity, a
response-control input per receiver for high-frequency-noise
filtering, TTL/DTL-compatible outputs with a 2 kΩ internal pull-up to
VCC. The companion driver is the [Am2616](../am2616/README.md).

First introduced: **1979*** — the earliest located dated AMD
documentation is the 1979 Linear and Interface Data Book. The bound is
retained rather than guessed.

## Interface (14-pin package, pins per LIC-419)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `in_a_i` | A IN, pin 1 | in | Receiver A data input |
| `out_a_o` | A OUT, pin 3 | out | Receiver A output |
| `in_b_i` | B IN, pin 4 | in | Receiver B data input |
| `out_b_o` | B OUT, pin 6 | out | Receiver B output |
| `in_c_i` | C IN, pin 10 | in | Receiver C data input |
| `out_c_o` | C OUT, pin 8 | out | Receiver C output |
| `in_d_i` | D IN, pin 13 | in | Receiver D data input |
| `out_d_o` | D OUT, pin 11 | out | Receiver D output |

Unmodeled pins: RESPONSE CONTROL A/B/C/D (pins 2, 5, 9, 12 — DC bias
node shaping the frequency response; no boolean effect); VCC pin 14;
GND pin 7.

## Boolean contract

Per the logic symbol and the switching thresholds (input rising to
+2.25 V switches the output LOW; falling below +0.75 V switches it
HIGH): the receiver inverts the line. In the boolean line model (1 =
positive/space level, 0 = negative/mark level):

```
out = !in      // per receiver
```

All 2^4 input combinations are defined combinationally; no state, no
undocumented encodings.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — the
hysteresis window (2.25 V/0.75 V typ at 25 °C), ±30 V input range,
response-control bias response, 2 kΩ pull-up, propagation delays — is
documented in the datasheet and out of scope here.

## Assumptions

- ASSUMPTION: the boolean input code stands for the RS-232C line
  level; the analog thresholds and hysteresis band are documented, not
  modeled. The response-control pins have no boolean effect.
