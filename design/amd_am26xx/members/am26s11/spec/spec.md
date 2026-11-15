# Am26S11 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-39 to 4-44 (truth tables for Am26S10 and
Am26S11 on page 4-41); identical reprint in the
[1979 Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-57 to 4-61, truth tables page 4-59). The same sheet documents
the inverting Am26S10 sibling; this specification reconstructs the
Am26S11 member only. The distinctive characteristics call out the
difference: "Input to bus is non-inverting on Am26S11" (against the
S10's inverting input).

## Part identity

Quad high-speed open-collector bus transceiver, pin-compatible with the
Am26S10, with the non-inverting driver: four open-collector bus
drivers (100 mA sink) gated by one active-low enable, and four separate
always-active inverting bus receivers tied to the same bus nodes.
Bus-compatible with the Am2905/2906/2907 party-line family.

First introduced: **1974*** — earliest located dated AMD documentation
is the 1974 Data Book itself; the bound is retained rather than
guessed.

## Interface (16-pin package — identical pin map to the Am26S10)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `e_n_i` | E, pin 12 | in | Enable, active low (all four drivers) |
| `i0_i` | I0, pin 4 | in | Channel 0 driver input |
| `b0_n_o` / `b0_i` | B0̄, pin 2 | out/in | Channel 0 bus line (driver / receiver role) |
| `z0_n_o` | Z0̄, pin 3 | out | Channel 0 receiver output |
| `i1_i` | I1, pin 5 | in | Channel 1 driver input |
| `b1_n_o` / `b1_i` | B1̄, pin 7 | out/in | Channel 1 bus line |
| `z1_n_o` | Z1̄, pin 6 | out | Channel 1 receiver output |
| `i2_i` | I2, pin 11 | in | Channel 2 driver input |
| `b2_n_o` / `b2_i` | B2̄, pin 9 | out/in | Channel 2 bus line |
| `z2_n_o` | Z2̄, pin 10 | out | Channel 2 receiver output |
| `i3_i` | I3, pin 13 | in | Channel 3 driver input |
| `b3_n_o` / `b3_i` | B3̄, pin 15 | out/in | Channel 3 bus line |
| `z3_n_o` | Z3̄, pin 14 | out | Channel 3 receiver output |

Unmodeled pins: VCC pin 16; GND1 pin 1; GND2 pin 8. The bus role split
follows the [Am26S10 spec's](../am26s10/spec/spec.md) port-structure
note; the testbench ties each pair onto one net with pull-up bias and
directs the party-line resolution.

## Boolean contract

Per the truth tables (non-inverting driver; inverting receiver):

| Ē | I | B̄ | Z̄ |
|---|---|---|---|
| L | L | L | H |
| L | H | H | L |
| H | X | Y | Ȳ |

```
enabled = !E
B̄ = enabled ? I : 'Z       // open-collector release (non-inverting)
Z̄ = !B̄                      // receiver, always active
```

With pull-up bias on the released bus, the released rows read B̄ = H
and Z̄ = L.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — the
S11/S10 shared envelope (open-collector sinking, pull-up biasing, 2.0 V
receiver switching point, PNP inputs, delays) — is documented in the
datasheet and out of scope here.

## Assumptions

- ASSUMPTION: the digital contract equals the Am26S10's except for the
  driver polarity (B̄ = I instead of !I), per the two truth tables on
  the shared datasheet page and the distinctive-characteristics line.
- ASSUMPTION: the bus role split (driver/receiver ports for one
  physical pin) is a verification-flow accommodation, exercised
  end-to-end in the testbench.
- Documented as unmodeled electrical behavior: sink capability,
  switching points, loading, delays.
