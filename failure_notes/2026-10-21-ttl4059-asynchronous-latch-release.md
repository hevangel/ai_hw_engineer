# 4059 output latch release with the clock stopped

## Detection and independent evidence

Integration review of the first 4059 model found LE was sampled only on CP
edges. Its lint, simulation and synthesis had passed. TI's
[CD74HC4059 datasheet](https://www.ti.com/lit/gpn/cd74hc4059), page 2, says the
latched output remains high until LE returns low; page 5 specifies LE-to-Q
propagation. This establishes a logical control independent of clock edges.
Source SHA-256: `978743573F24A3801075948B497C3E73E13BE0E0CCC00A3DEBBF234DC971F175`.

## Root cause and missed coverage

The initial model treated asynchronous control as an omitted analog timing
feature. Its tests changed LE around subsequent CP pulses, so RTL and test
shared an edge-only assumption and never checked a stopped-clock release.

## Correction and verification

The output now combines the ordinary one-CP-cycle pulse with a level-sensitive
hold latch. Low LE clears the held extension asynchronously; it does not shorten
an ordinary pulse still active at the CP pulse source. A regression holds CP
static after extending a pulse, lowers LE, and asserts Q clears before any clock
edge. Strict Verilator lint, xezim simulation and Yosys synthesis/check pass;
current-source fingerprints are published in the library report.

## Prevention

Source review must distinguish omitted physical propagation delay from native
logical asynchronous controls. Review control-to-output timing-table entries
alongside truth tables, and test level controls with the clock stopped. The
library specification and continuation plan now state this distinction.
