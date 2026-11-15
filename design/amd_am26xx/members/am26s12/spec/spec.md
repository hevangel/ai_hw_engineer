# Am26S12 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-39 to 4-44 (shared Am26S10/S11/S12 sheet:
connection diagram and logic diagram page 4-39, truth table page 4-41),
qualified against the dedicated
[1979 Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
sheet pages 4-62 to 4-66 (logic diagram LIC-380, connection diagram
LIC-382, electrical characteristics page 4-63, truth table page 4-65,
performance curves and receiver input characteristics figures 3-4).
The same 1979 sheet documents the Am26S12A grade (see the ledger
below); this specification reconstructs the Am26S12 grade, and the
[Am26S12A member](../am26s12a/spec/spec.md) verifies the same source at
its own grade per the parent issue's revision rule.

## Part identity

Quad high-speed bus transceiver: four open-collector inverting bus
drivers (100 mA sink at 0.7 V typically) controlled by an active-LOW
two-input AND gate (both enable pins low), and four separate
always-active bus receivers with input hysteresis and TTL outputs
driving ten TTL loads. The receiver hysteresis is chosen so the output
switches HIGH when the input at a HIGH level moves to 1.4 V typically
and LOW when the input at a LOW level moves to 2.0 V typically, making
the receiver very insensitive to bus noise.

First introduced: **1974*** — the 1974 Data Book documents the part on
the shared Am26S10/S11/S12 sheet; the bound is retained rather than
guessed (no month-level claim).

## Interface (16-pin package, pins per LIC-382)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `e1_n_i` | E, pin 7 | in | Enable 1, active low |
| `i0_i` | I0, pin 2 | in | Channel 0 driver input |
| `b0_n_o` / `b0_i` | B0̄, pin 1 | out/in | Channel 0 bus line (driver / receiver role) |
| `z0_n_o` | Z0̄, pin 3 | out | Channel 0 receiver output |
| `i1_i` | I1, pin 5 | in | Channel 1 driver input |
| `b1_n_o` / `b1_i` | B1̄, pin 4 | out/in | Channel 1 bus line |
| `z1_n_o` | Z1̄, pin 6 | out | Channel 1 receiver output |
| `i2_i` | I2, pin 11 | in | Channel 2 driver input |
| `b2_n_o` / `b2_i` | B2̄, pin 12 | out/in | Channel 2 bus line |
| `z2_n_o` | Z2̄, pin 10 | out | Channel 2 receiver output |
| `i3_i` | I3, pin 14 | in | Channel 3 driver input |
| `b3_n_o` / `b3_i` | B3̄, pin 15 | out/in | Channel 3 bus line |
| `z3_n_o` | Z3̄, pin 13 | out | Channel 3 receiver output |

Unmodeled pins: VCC pin 16; GND pin 8. The bus role split follows the
[Am26S10 spec's](../am26s10/spec/spec.md) port-structure note.

## Boolean contract

Per the truth table (page 4-65; the same rows appear on the 1974 sheet
page 4-41):

| Ē1 | Ē2 | I | B̄ | Z̄ |
|---|---|---|---|---|
| L | L | L | H | L |
| L | L | H | L | H |
| H | X | X | Y | Ȳ |
| X | H | X | Y | Ȳ |

```
enabled = !E1 && !E2          // active-low two-input AND
B̄ = enabled ? !I : 'Z         // open-collector release
Z̄ = !B̄                        // receiver, always active
```

With pull-up bias on the released bus, the released rows read B̄ = H
and Z̄ = L. All input combinations are defined.

## Receiver hysteresis grade (the S12 contract)

The S12 grade's receiver thresholds, per the 1979 electrical
characteristics table: VIH (input HIGH threshold) 1.8/2.0/2.2 V
min/typ/max; VIL (input LOW threshold) 1.2/1.4/1.6 V; threshold margin
guaranteed greater than 0.4 V. These are electrical constants recorded
in the RTL's elaboration-time margin check and here; the digital
function does not depend on them. The bus is modeled at the binary
level, so hysteresis (a property of the analog switching region) is
outside the digital contract.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — 100 mA
sink, bus leakage, switching delays, hysteresis figures, ICC — is
documented in the datasheet and out of scope here.

## Assumptions

- ASSUMPTION: the digital contract is identical for the S12 and S12A
  grades (one truth table across both printings and both grades); the
  grade difference is the receiver threshold pair, recorded as
  documented constants with the datasheet's margin guarantee checked at
  elaboration.
- ASSUMPTION: the bus role split (driver/receiver ports for one
  physical pin) is a verification-flow accommodation, exercised
  end-to-end in the testbench.
- Documented as unmodeled electrical behavior: thresholds, hysteresis,
  sink capability, delays.
