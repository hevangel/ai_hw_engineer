# Am26S10 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-39 to 4-44 (PDF pages 372-377): functional
description, logic diagram and connection diagram on 4-39; electrical
characteristics on 4-40; truth tables and switching characteristics on
4-41 (TRUTH TABLES for Am26S10 and Am26S11, driver and receiver rows).
The identical part is reprinted in the
[1979 Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-57 to 4-61, truth tables on 4-59); both printings agree. The
same sheet also documents the non-inverting Am26S11 sibling; this
specification reconstructs the Am26S10 member only.

## Part identity

Quad high-speed open-collector bus transceiver: four inverting
open-collector bus drivers (100 mA sink at 0.8 V maximum) gated by one
active-low enable E, and four separate always-active inverting bus
receivers internally tied to the same bus nodes, with Schottky TTL
receiver outputs driving ten Schottky unit loads. Two ground pins
improve decoupling. Bus-compatible with the Am2905/2906/2907 family for
party-line operation; the enable input can be driven by active-low
decoders such as the Am25LS139.

First introduced: **1974*** — earliest located dated AMD documentation
is the 1974 Data Book itself; the bound is retained rather than
guessed.

## Interface (16-pin package, pins per the connection diagram)

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

Unmodeled pins: VCC pin 16; GND1 pin 1; GND2 pin 8.

## Port-structure note (bus role split)

Physically each B̄ pin is one bidirectional open-collector bus net
serving two roles: driver output and receiver input. The reconstruction
exposes the two roles as separate ports — `b#_n_o` (tristate driver
output) and `b#_i` (receiver bus input) — because the verification
flows differ in what they can express: Verilator/xezim simulate the
tied net with pull-up bias and the two-instance party line directly
(`pullup` primitives; note that weak-strength continuous assignments
are mis-modeled by Verilator 5.052 and are not used), while Yosys
formal has no pull-up primitive and no inout directionality, so the
split-port structure keeps each role unambiguously provable. The
testbench ties each pair onto one net and directs the party-line
resolution.

## Boolean contract

Per the truth tables (inverting driver; inverting receiver; Y = bus
level set by another transceiver):

| Ē | I | B̄ | Z̄ |
|---|---|---|---|
| L | L | H | L |
| L | H | L | H |
| H | X | Y | Ȳ |

```
enabled = !E
B̄ = enabled ? !I : 'Z      // open-collector release
Z̄ = !B̄                      // receiver, always active
```

With pull-up bias on the released bus (the open-collector idle state),
the released rows read B̄ = H and Z̄ = L. All input combinations are
defined; the 3-state bus release is a pure function of E.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — open-
collector sinking (100 mA at 0.7 V typical), pull-up biasing, the 2.0 V
receiver switching point, PNP input loading, propagation delays
(tPLH/tPHL 10/15 ns input-to-bus, 10/15 ns bus-to-receiver) — is
documented in the datasheet and out of scope here.

## Assumptions

- ASSUMPTION: the bus role split (driver/receiver ports for one
  physical pin) is a verification-flow accommodation, described above
  and exercised end-to-end (tie + bias + party line) in the testbench.
- ASSUMPTION: the released-bus idle level is high via pull-up bias
  (open-collector); the receiver-while-released behavior is verified
  against that bias in simulation.
- Documented as unmodeled electrical behavior: sink current, switching
  points, input loading, delays.
