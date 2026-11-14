# Am26LS30 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf),
printed pages 4-30 to 4-35 (PDF pages 262-266): distinctive
characteristics, functional description, logic diagrams for both modes
(BLI-002 RS-423 mode HIGH, BLI-003 RS-422 mode LOW) and connection
diagram (BLI-005) on page 4-30; DC characteristics on 4-31/4-32; the
published FUNCTION TABLE on page 4-34; switching waveforms on 4-33.
The part first appears in the
[1978 AMD Schottky and Low-Power Schottky Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1978_AMD_Schottky_and_Low-Power_Schottky_Data_Book_including_Digital_Signal_Processing_Handbook_Second_Edition_197807.pdf)
(PDF pages 310-312).

## Part identity

Dual differential RS-422 party-line / quad single-ended RS-423 line
driver: a MODE control pin selects the configuration. In RS-423 mode
(four independent non-inverting drivers) 35 mW/driver typical; in
RS-422 mode (two differential drivers with complementary outputs and
individual three-state controls) 35 mW/driver typical. Outputs do not
clamp the line with power off or in hi-impedance state; low-current
PNP inputs are TTL/MOS/CMOS compatible.

First introduced: **1978*** — earliest located dated AMD documentation
is the July 1978 Schottky and Low-Power Schottky Data Book; the bound
is retained rather than guessed (no month-level claim).

## Interface (16-pin package, pins per BLI-005)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `in_a_i` | INPUT A, pin 2 | in | Driver A data input (RS-422: pair 1 data) |
| `in_b_i` | INPUT/ENABLE B, pin 3 | in | RS-423: driver B data; RS-422: pair 1 enable, active low |
| `mode_i` | MODE, pin 4 | in | 1 = RS-423 quad single-ended; 0 = RS-422 dual differential |
| `in_c_i` | INPUT/ENABLE C, pin 6 | in | RS-423: driver C data; RS-422: pair 2 enable, active low |
| `in_d_i` | INPUT D, pin 7 | in | Driver D data input (RS-422: pair 2 data) |
| `out_a_o` | OUTPUT A, pin 15 | out | Output A (RS-422 pair 1 true) |
| `out_b_o` | OUTPUT B, pin 14 | out | Output B (RS-422 pair 1 complement) |
| `out_c_o` | OUTPUT C, pin 11 | out | Output C (RS-422 pair 2 true) |
| `out_d_o` | OUTPUT D, pin 10 | out | Output D (RS-422 pair 2 complement) |
| `sr_a_i` | SLEW RATE CONTROL A, pin 16 | in | Analog-only pin |
| `sr_b_i` | SLEW RATE CONTROL B, pin 13 | in | Analog-only pin |
| `sr_c_i` | SLEW RATE CONTROL C, pin 12 | in | Analog-only pin |
| `sr_d_i` | SLEW RATE CONTROL D, pin 9 | in | Analog-only pin |

Unmodeled pins: VCC pin 1; GND pin 5; VEE pin 8 (tied to GND in the
RS-422 MIL connection).

## Boolean contract

From the published function table (page 4-34), verified row by row:

MODE = 1 (RS-423, quad single-ended, all outputs always driven):

| A | B | C | D | out_A | out_B | out_C | out_D |
|---|---|---|---|---|---|---|---|
| x | x | x | x | A | B | C | D |

MODE = 0 (RS-422, dual differential party-line; the function table's
A(D)/B(C) column naming covers both pairs):

| data | enable | out_true | out_comp |
|---|---|---|---|
| 0 | 0 | 0 | 1 |
| 0 | 1 | Z | Z |
| 1 | 0 | 1 | 0 |
| 1 | 1 | Z | Z |

i.e. pair 1: `out_a = !in_b ? in_a : 'Z`, `out_b = !in_b ? !in_a : 'Z`;
pair 2: `out_c = !in_c ? in_d : 'Z`, `out_d = !in_c ? !in_d : 'Z`.

## Timing boundary and electrical envelope

Zero-delay combinational reconstruction. Electrical behavior — RS-422
100 Ω differential drive / RS-423 output swing from the VCC/VEE
supplies, slew-rate figures, three-state enable/disable times,
short-circuit protection — is documented in the datasheet and out of
scope here.

## Assumptions

- ASSUMPTION: the slew-rate-control pins have no boolean effect and
  are exposed as documented unused inputs preserving the physical pin
  map.
- ASSUMPTION: the RS-422 enable polarity (B/C pins active low) and the
  non-inverting RS-423 outputs follow the published function table and
  the BLI-003 logic diagram (OUT B/OUT D carry the inverted output of
  their pair).
