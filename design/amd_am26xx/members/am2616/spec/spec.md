# Am2616 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-78 to 4-82 (PDF pages 310-313): functional description,
logic symbol (LIC-411), circuit diagram (LIC-412) and connection
diagram (LIC-413) on page 4-78; electrical characteristics on 4-79/
4-80. The MIL-188C/RS-232C conformance is stated on page 4-78.

## Part identity

Quad line driver meeting EIA RS-232C, CCITT V.24 and MIL-188C: four
DTL/TTL-compatible inverting outputs, supply-independent output swing
(from VCC pin 16 and VEE pin 9), internal slew-rate limiting, short-
circuit protected outputs, and per-driver inhibit inputs. Driver A
accepts two data inputs; drivers B, C and D accept one input each
(logic symbol LIC-411).

First introduced: **1979*** — the earliest located dated AMD
documentation is the 1979 Linear and Interface Data Book (the part
does not appear in the 1974 Data Book or the 1977/1978 books'
Am2614/2615 sheets). The bound is retained rather than guessed.

## Interface (16-pin package, pins per LIC-413)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `in_a1_i` | INPUT A1, pin 1 | in | Driver A data input |
| `in_a2_i` | INPUT A2, pin 2 | in | Driver A data input |
| `inhibit_a_i` | INHIBIT A, pin 3 | in | Driver A inhibit, active high |
| `out_a_o` | OUTPUT A, pin 4 | out | Driver A output |
| `in_b_i` | INPUT B, pin 5 | in | Driver B data input |
| `inhibit_b_i` | INHIBIT B, pin 6 | in | Driver B inhibit, active high |
| `out_b_o` | OUTPUT B, pin 7 | out | Driver B output |
| `in_c_i` | INPUT C, pin 12 | in | Driver C data input |
| `inhibit_c_i` | INHIBIT C, pin 11 | in | Driver C inhibit, active high |
| `out_c_o` | OUTPUT C, pin 10 | out | Driver C output |
| `in_d_i` | INPUT D, pin 15 | in | Driver D data input |
| `inhibit_d_i` | INHIBIT D, pin 14 | in | Driver D inhibit, active high |
| `out_d_o` | OUTPUT D, pin 13 | out | Driver D output |

Unmodeled pins: VCC pin 16; VEE pin 9; GND pin 8.

## Boolean contract

Per the logic symbol (each driver: data AND-gate followed by an
inhibit OR and an inverting output):

```
out_a = !((in_a1 && in_a2) || inhibit_a)
out_b = !(in_b || inhibit_b)
out_c = !(in_c || inhibit_c)
out_d = !(in_d || inhibit_d)
```

"A HIGH logic level on the inhibit input forces the driver output to
VOL or to mark state": inhibit = 1 pins the output LOW in this boolean
model (RS-232C mark). With the inhibit low, the output follows the
inverted data function. All 2^8 input combinations are defined
combinationally; no state, no undocumented encodings.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — output
swing versus supplies, internal slew-rate limiting (and its external-
capacitor option), short-circuit protection, MIL-188C output impedance
(< 100 Ω), ±10% amplitude matching, propagation delays — is documented
in the datasheet and out of scope here.

## Assumptions

None at the digital level: the logic symbol and connection diagram fix
the function and pin map completely.
