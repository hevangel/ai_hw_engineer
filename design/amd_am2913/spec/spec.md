# Am2913 digital specification

Primary source: [1979 AMD Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf),
PDF161–165 / printed2-153–2-157. Functional description and logic diagram are
on PDF161; the complete truth tables are on PDF164, visually inspected for
active-low pins. First-introduction year is not established; documented by1978
in the earlier family book, PDF109–113.

The device is an asynchronous eight-input priority encoder/interrupt expander.
All request inputs and EI are active low. I7 has highest priority, I0 lowest.
The three A outputs encode the highest requesting input in **positive binary**.
EI HIGH disables encoding and drives code000; with EI LOW and no request,
code000 is also driven. EO is an active-low cascade output: LOW only when EI
is LOW and all eight requests are HIGH. Any active request or disabled EI
makes EO HIGH, preventing a lower-priority chip from responding.

Five independent gates control only the A three-state outputs. G1/G2 must
both be HIGH; G3/G4/G5 must all be LOW. Gating does not affect EO. EI is not
an output-enable pin: an EI-disabled encoder still drives000 if the gates
permit. There is no clock, reset or storage. Model A using a three-bit value
plus a common enable signal for external digital bus resolution.

ASSUMPTION: pins are evaluated after combinational settling; propagation
delays, analog levels and contention are outside this synthesizable model.
Released A retains the combinational code, but the value is irrelevant while
its enable is false. Verify this with all 16,384 input vectors, actual
two-chip EI/EO cascading and a nine-chip 64-request encoder hierarchy.
The latter uses Am2913 at every level; it does not substitute for the original
eight-Am2914 application pictured on PDF165. Its vector/status variants are
now verified in the [Am2914 application regression](../../amd_am2914/report/final_report.md).
