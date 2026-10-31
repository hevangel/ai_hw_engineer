# Am2914 digital specification

Primary sources: AMD [1979 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf)
PDF166–190 (printed2-158–2-182), and [January1987 standalone datasheet](https://bitsavers.trailing-edge.com/components/amd/bitslice/_dataSheets/1987_2914.pdf).
The earlier [1978 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf)
already documents Am2914; exact first shipment year has not been established.

## Native state and instructions

Eight active-low P inputs feed eight pulse-catching latches and a positive-edge
interrupt register. LB HIGH makes the latches transparent; LB LOW retains
negative pulses until cleared. Mask bits1 inhibit individual requests. Highest
unmasked pending bit7 wins. Three-bit status is the minimum permitted vector;
comparison is inclusive. Native CP is positive-edge (the detailed diagrams
use an inverted internal clock). There is no reset pin or defined startup;
instruction0 performs master clear.

All16 instructions in TableI/PDF168 are implemented. IE HIGH disables only
instruction effects; interrupt input sampling and live cascade outputs continue.
Mask operations are load/read/clear/set/bit-clear/bit-set. Read mask and clear
from mask both drive M; the latter uses internal mask data and requires the
external M bus to float. Load status stores S only if GE is LOW, otherwise
stores0; GS simultaneously takes GE. Read status drives S only if GS is LOW.
Read vector drives V only for an eligible group, updates its status to V+1,
and clears other groups' status. It loads the hold-vector register regardless
of eligibility and marks vector-clear enable only in the eligible group.
Clear-last-vector uses the held value, not the current encoder output, and
clears its enable. Master/clear-all also clear vector hold/enable.

Clear instructions remove selected pulse-latch contents during CP LOW and
selected interrupt-register bits at the rising edge. Live LOW P has set
priority in its pulse latch; the clocked request is nevertheless suppressed
by a clear operation. The request register otherwise samples captured/level
inputs every edge; it is not an additional sticky queue in bypass mode.

## Cascade and output rules

ID LOW disables this group's eligibility. Eligibility additionally requires
an unmasked request and vector>=status. It is independent of the software
interrupt-request enable flip-flop; that flip-flop controls only the open-
collector IRQ output. Vector output eligibility and cascade priorities still
work after DISIN. Represent IRQ as a pull-low value; other bidirectional buses
have explicit value and enable ports.

PD HIGH if GS LOW or an unmasked request passes priority; RD LOW if PD HIGH
or ID LOW. GAS LOW only during an enabled Read Vector of vector7 in an
eligible group. Master clear loads GS from GAR, enabling the lowest group when
GAR is tied LOW. Load status loads GS from GE. On Read Vector GS becomes HIGH
if GAR is HIGH and no unmasked request exists, if GAS is LOW, or if ID is LOW;
otherwise LOW. This is the explicit functional description on PDF187.

SV is LOW after reading vector7, and stays LOW until master clear or load
status; the latter restore it HIGH. Highest group's SV is wired to its own ID
in the original application. Lower SV outputs are unused. Eight groups use
RD-to-ID connections from high to low and GAS-to-GAR from low to high, with
Am2913 encoding high vector/status bits (Figures6/9/10, PDF178/181/182).

## Assumption ledger and source interpretation

ASSUMPTION: settled digital pins respect native CP setup/hold. Eight LOW-phase
sample-hold bits represent the D value immediately before the edge, avoiding
zero-delay release of the clear pulse at CP rising. These are simulator timing
adapters, not a claim of eight additional physical chip latches. Verify both
CP phases and sub-cycle input pulses.

ASSUMPTION: the explicit functional descriptions resolve ambiguous circuit
drawings. In Figure7 the DET overbar/bubble transcription does not reliably
express the paragraph's no-request group update. Use the paragraph on PDF187,
and validate it with the original 64-level cascade wiring. The abbreviated
H control of Figure9 does not by itself specify sticky overflow on later
ineligible vector reads; use the explicit SV persistence rule in the original
application (PDF178) and January1987 pin description (PDF5). Validate highest
vector disable, intervening instructions and status reload in real original
interrupt sequences before sign-off.

ASSUMPTION: released bus values are irrelevant; analog levels, delays,
metastability, simultaneous contention and minimum pulse widths are outside
this synthesizable contract. Unknown startup is exercised through native
master clear, not initialized registers or an invented reset.
