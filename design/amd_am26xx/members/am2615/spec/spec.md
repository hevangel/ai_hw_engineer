# Am2615 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-51 to 4-56 (PDF pages 384-389): functional
description, logic diagram and connection diagram on 4-51; DC
characteristics on 4-52; strobe transfer characteristics on 4-54;
switching test circuit, frequency-response figure and loading rules on
4-55. The identical part is reprinted in the
[1979 Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-72 to 4-77, logic diagram LIC-399). The same sheet documents
the Am9615 (input threshold ~0 V, no fail-safe); this specification
reconstructs the Am2615 member only.

## Part identity

Dual differential line receiver: ±15 V common-mode range, 3 V single-
ended or differential data reception (±500 mV differential on the
Am9615), per-receiver strobe, internal 130 Ω input terminating resistor,
response-time control via an external capacitor, and per-receiver
uncommitted-collector output with an optional active pull-up network.
The Am2615 adds fail-safe protection: "the output going to a LOW state
when the inputs are open or disconnected."

First introduced: **1974*** — earliest located dated AMD documentation
is the 1974 Data Book itself; the bound is retained rather than guessed.

## Interface (16-pin package)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `a_in_p_i` | +INPUT A, pin 5 | in | Receiver A differential line + |
| `a_in_n_i` | -INPUT A, pin 7 | in | Receiver A differential line − |
| `a_strobe_i` | STROBE A, pin 3 | in | Receiver A strobe, active high |
| `a_out_o` | OUTPUT A, pin 1 | out | Receiver A output |
| `b_in_p_i` | +INPUT B, pin 11 | in | Receiver B differential line + |
| `b_in_n_i` | -INPUT B, pin 9 | in | Receiver B differential line − |
| `b_strobe_i` | STROBE B, pin 13 | in | Receiver B strobe, active high |
| `b_out_o` | OUTPUT B, pin 15 | out | Receiver B output |

Unmodeled pins: ACTIVE PULL-UP A/B (pins 2/14, selects the active
pull-up output network; no boolean effect); RESPONSE CONTROL A/B
(pins 4/12, comparator-output node for an external frequency-response
capacitor; no boolean effect); 130 Ω A/B (pins 6/10, internal
terminating resistor connection); VCC pin 16; GND pin 8.

## Boolean contract

Per the logic diagram (LIC-399) and the strobe transfer
characteristics:

```
COMP = (VIN+ > VIN-)          // differential comparator decision
OUT  = !(COMP && STROBE)      // strobe LOW holds the output HIGH
```

The differential decision is modeled on binary line states:
`COMP = in_p && !in_n` for the two defined differential states. The
equal-inputs code stands for the open/undriven line; the Am2615's
documented fail-safe resolves it as COMP = 1 (OUT LOW with strobe
high), i.e. `COMP = (in_p >= in_n)` in the binary model.

## Pin-label print error (source conflict resolution)

The 1974 loading-rules table (page 4-55) labels pin 3 "Response
Control" and pin 4 "Strobe" for receiver A (and 12/13 swapped for
receiver B). Three independent figures in the same sheets agree on the
opposite assignment: the 1979 logic diagram (LIC-399) routes pin 3/13
into the output gate and pin 4/12 onto the comparator-output node, the
1974 switching-time test circuit (Figure 4) clamps capacitance
"(PIN 4 OR 12)" and takes the switching strobe "(PIN 3 OR 13)", and the
frequency-response figure marks "RESPONSE CONTROL PIN (PIN 4 OR 12)".
The loading-rules table rows are a print swap; the pin numbers are
identical either way and this reconstruction follows the three-figure
majority.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — input
threshold (−1.5 V Am2615, ~0 V Am9615), ±15 V common-mode range,
response control timing (cutoff frequency versus capacitor), strobe
transfer curves, active pull-up versus open-collector output
structures, loading rules (1.5 unit loads per strobe, 0.5 per input) —
is documented in the datasheet and out of scope here.

## Assumption ledger

- ASSUMPTION: the equal-inputs binary code represents the open/undriven
  line and resolves to COMP = 1 per the documented Am2615 fail-safe;
  the continuous analog comparator behavior (threshold, hysteresis,
  common-mode limits) is not modeled.
- ASSUMPTION: the active pull-up and response-control pins have no
  boolean effect and are documented as unmodeled.
- Source conflict resolved above (loading-rules table label swap) is a
  documented finding, not a modeling assumption.
