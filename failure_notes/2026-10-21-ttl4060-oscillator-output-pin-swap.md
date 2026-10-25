# 74HC4060 oscillator-output pins swapped during implementation

## Discovery and impact

A second high-resolution review of the TI positive-logic diagram caught reversed
CLK pin-9/pin-10 buffer outputs in an uncommitted model. The divider itself was
correct. The local test passed because its expected buffer polarity repeated the
same diagram misreading. The incorrect model was corrected before publication.

## Independent source

[TI SN74HC4060 SCLS161D](https://www.ti.com/lit/ds/symlink/sn74hc4060.pdf),
pages 1–2: CLR high makes the complementary CLKO pin 10 high and CLKO pin 9 low.
The diagram's pin-10 wire branches before the inverter; pin 9 branches after it.
Thus pin 9 is CLKI AND NOT CLR; pin 10 is its complement. The initial review
mistook the branch endpoints when following the adjacent wires.

## Correction and verification

Corrected RTL, specification and expected physical output levels against the
manufacturer's explicit reset statement and separately traced pin branches.
The regression checks both buffer levels throughout two complete counter periods,
wrong-edge hold, and stopped-clock resets at both clock levels. Re-ran strict
lint, simulation and generic synthesis after the RTL correction.

## Prevention

For gate diagrams with complementary outputs, verify both physical pin numbers
against a separate explicit reset or truth-table statement. A self-written
reference that repeats the same wire-tracing mistake is insufficient evidence.
