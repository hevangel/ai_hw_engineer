# Am26S12A functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-62 to 4-66 (PDF pages 294-297): functional description,
logic diagram (LIC-380) and connection diagram (LIC-382) on page 4-62;
electrical characteristics page 4-63 (the S12 vs S12A receiver
threshold rows); switching circuits and waveforms page 4-64; truth
table page 4-65; receiver input characteristic curves (figures 3 and
4, per grade) page 4-65. The 1974 Data Book documents the same part on
its shared Am26S10/S11/S12 sheet (pages 4-39..4-44).

## Part identity

"Functionally identical to the Am26S12 but has a different hysteresis
characteristic so that the output switches when the input is typically
at 1.2 volts or 2.25 volts" (1979 functional description): the same
quad open-collector bus transceiver — inverting drivers behind an
active-low two-input AND enable, always-active inverting receivers —
with the S12A receiver grade. Threshold margin greater than 0.4 V in
both grades; the S12A's wider threshold spread moves the receiver's
switching points away from the TTL midpoint for noisier bus
environments.

First introduced: **1974*** — the 1974 Data Book documents
Am26S12/26S12A together (connection-diagram column lists both grade
order numbers); the bound is retained rather than guessed.

## Interface (16-pin package — identical pin map to the Am26S12)

Identical to the [Am26S12 spec](../am26s12/spec/spec.md) interface
table (E pins 7/9; I0/I1/I2/I3 pins 2/5/11/14; B0-B3 pins 1/4/12/15;
Z0-Z3 pins 3/6/10/13; VCC pin 16; GND pin 8), with the same bus role
split for verification.

## Boolean contract

Identical to the [Am26S12](../am26s12/spec/spec.md) contract — one
truth table serves both grades (page 4-65):

```
enabled = !E1 && !E2
B̄ = enabled ? !I : 'Z
Z̄ = !B̄
```

## Receiver hysteresis grade (the S12A contract)

The S12A grade's receiver thresholds, per the 1979 electrical
characteristics table: VIH 2.05/2.25/2.45 V min/typ/max; VIL
1.0/1.2/1.4 V; threshold margin greater than 0.4 V guaranteed. These
are electrical constants recorded in the shared source's elaboration-
time margin check and here; the digital function does not depend on
them.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction; the electrical envelope
(including the S12A hysteresis figures) is documented, not modeled.

## Assumptions

- ASSUMPTION: the digital contract is identical to the Am26S12's (one
  published truth table for both grades); the S12A grade difference is
  the receiver threshold pair (2.25/1.2 V typ against the S12's
  2.0/1.4 V), recorded as documented constants with the margin
  guarantee checked at elaboration.
- ASSUMPTION: the bus role split (driver/receiver ports for one
  physical pin) is a verification-flow accommodation, exercised
  end-to-end in the testbench.
