# Am29331 digital specification

Primary contract: AMD 1988 *Am29C300/29300 Data Book*, "Am29331 16-Bit
Microprogram Sequencer", Issue 05729E/0 (December 1987), PDF 128–163 of
[the bitsavers scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf).
Cross-check source: AMD 1985 *Am29300 Family Handbook* advanced-information
datasheet (PDF 100–112 of
[that scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1985_AM29300_Family_Handbook.pdf)).
All registers update on CP rising edges; RST is synchronous and active low
(the 1988 pin list states "RST — Reset (Input, Active LOW)"; both prose
passages that name levels are consistent with active low once "RESET = LOW"
is read as the inactive level).

Sixteen-bit address, data, counter and comparison registers; a 33-word
16-bit stack with a modulo-64 stack pointer; 64 instructions in four
classes; a sixteen-way test multiplexer over T0–T11; a breakpoint
comparator with EQUAL output; single-level interrupts with INTA and an
automatic return-address push; trap support through FC and C̄IN; HOLD;
master/slave error checking through ERROR.

## Pin contract

| Pin | Direction | Contract |
| --- | --- | --- |
| CP | in | clock; everything samples at the LOW-to-HIGH edge |
| RST | in, active low | synchronous; selects address 0, EQUAL low, SP←0, comparison disabled; counter/comparison-register contents retained; stack contents invalid |
| I5–I0 | in | instruction; FC overrides with CONTINUE; reset overrides both |
| T11–T0 | in | twelve external tests; S selects one of sixteen conditions |
| S3–S0 | in | condition select; 8=C, 9=N, A=V, B=Z, C=C+Z, D=C̄+Z, E=N⊕V, F=(N⊕V)+Z |
| D15–D0 | bidir, 3-state | branch addresses/counter data in; SP (TOS for POP D) out; driver on when OED·R̄ST·H̄OLD·S̄LAVE |
| A15–A0 | in | alternate branch address and counter load data |
| M3–M0 ×4 | in | four 4-bit multiway sets; D1 D0 picks the set replacing D3–D0 |
| Y15–Y0 | bidir, 3-state | next address out; interrupt vector in; released during HOLD, SLAVE, and an accepted interrupt |
| FC | in, active high | force CONTINUE (trap select with C̄IN) |
| C̄IN | in, active low | incrementer carry; high freezes PC (trap return address) |
| OED | in, active high | D-bus driver enable |
| HOLD | in, active high | three-states Y/INTA/A-FULL/EQUAL (D via OED gating) and freezes all state |
| INTR, INTEN | in | request/enable; accept = INTR·INTEN·R̄ST·H̄OLD |
| INTA | bidir, 3-state, active low | low while an interrupt is accepted |
| A-FULL | bidir, 3-state | SP ≥ 28 (6-bit pointer; underflow SP=63 also active) |
| EQUAL | bidir, 3-state | comparison enabled and interrupt-multiplexer address equals R |
| ERROR | out, active high | driven-value vs observed-pin mismatch on any enabled bidirectional output (contention as master, computed-vs-driven as slave) |
| SLAVE | in, active high | all bidirectional outputs become inputs except ERROR |

## Architecture and cycle model

The address multiplexer selects INC (AR+1 when C̄IN low, AR when high), D,
A, multiway {D15–D4, Mset[D1 D0]}, TOS, or zero at reset. The address
register is clocked every cycle from the interrupt multiplexer (address-mux
output normally; the Y-bus value while INTR·INTEN·R̄ST·H̄OLD). The
interrupt return address register latches the address-mux output every
cycle. Cond. = (Test[S] OR I5) XOR I4; class 11 always takes its single
unconditional row. END FOR rows (I3–I0 = 3/7/B/F in classes 0–2) always
decrement the counter and branch only when the condition passes AND C≠1;
the TOS variants (xF, opcode 0F/1F/2F) also pop when the branch is not
taken.

Interrupts: the interrupted instruction completes normally at the accept
edge; IRAR latches the address-mux output (the return address); one cycle
later the hardware pushes IRAR onto the stack. The microinstruction in
that following cycle must not use the stack (datasheet: undefined if it
does). A RETURN ends the routine. Traps (FC=1, C̄IN=1) make the address
multiplexer select the address register itself, so IRAR latches the
trapped microinstruction's own address and re-execution follows the routine
RETURN. HOLD has priority over interrupts and freezes every clocked update;
it gates Y/INTA/A-FULL/EQUAL combinationally (1988 page 3-11 names exactly
those four outputs).

Instruction actions are defined by the external table transcription in
`../references/instructions.csv` (Tables 1 and 2, visually checked from
page images before RTL). CALL TOS pops and pushes the return address in one
edge: one top-slot write, pointer unchanged. PUSH writes the incrementer
output (AR+1, or AR with C̄IN high); FOR pushes AR+1 and loads the counter
from D or A; RESET SP zeroes the pointer; SWAP exchanges counter and TOS;
SET/CLEAR control the comparison register R and its enable. The D-bus
outputs SP for every instruction except POP D, which outputs TOS.

## Stack addressing model

The stack pointer is a modulo-64 counter (1988 page 3-9); the array holds
33 words. Pushes write physical slot SP mod 33; TOS reads slot (SP−1) mod
33. This reproduces the documented behavior at the documented boundary:
the push onto a full stack (SP=33) overwrites the item at the bottom, and
a pop from an empty stack wraps the pointer to 63 so A-FULL (SP≥28) is
active during underflow exactly as the 1988 pin description states.
Slot contents beyond the first wrap, and any read through a stale or empty
TOS, are outside the documented contract; simulation masks them and formal
leaves them unconstrained.

## Assumption ledger and scope

- ASSUMPTION: 1985 advanced-information vs 1988 final. The 1988 final
  datasheet governs. Deltas observed: RST active low (1988 pin list; the
  1985 prose "OED = 1, RST = 1" driver note agrees, its "RESET = LOW"
  interrupt note names the inactive level); ERROR active-high output (1985
  said three-state); A-FULL defined as 28 ≤ SP ≤ 63 including underflow
  (1985 said SP ≥ 28); opcodes documented in hex.
- ASSUMPTION: HOLD entry/exit cycle granularity. The prose defers mode
  entry/exit "after the current cycle" while gating the same four outputs
  immediately; the RTL treats every HOLD=1 cycle as frozen (no clocked
  update, all outputs released) and every HOLD=0 cycle as active. The 1985
  text also gates the incrementer during hold; the 1988 text does not —
  the frozen-state model makes the distinction unobservable.
- ASSUMPTION: reset retains the counter and comparison register (only SP,
  PC, comparison enable and IRAR are documented as cleared; stack contents
  are declared invalid). The model retains the arrays' contents.
- ASSUMPTION: reset also cancels a latched interrupt push (RST wins at the
  edge; the datasheet says reset disregards interrupt requests and leaves
  stack contents invalid).
- ASSUMPTION: INTR held past its acceptance cycle keeps feeding the Y-bus
  value into the address register (the interrupt multiplexer select is
  combinational on INTR·INTEN). Real systems remove INTR after INTA;
  the datasheet does not specify held-request behavior.
- ASSUMPTION: the concurrent stack operation in the automatic-push cycle
  (datasheet-undefined) is resolved with the hardware push winning and the
  instruction's stack field suppressed for that cycle; counter/comparator
  effects of that instruction still apply.
- ASSUMPTION: deep overflow beyond the first wrap (SP > 34) and stale-slot
  reads map through the same mod-33 arithmetic for determinism, but they
  are masked from all verification checks (documented contract covers the
  first wrap and SP arithmetic only).
- ASSUMPTION: ERROR contention detection assumes each bidirectional pin's
  input pair observes the driven line (looped back in normal use,
  master-driven in slave mode). The mismatch form implements the 1988
  "malfunctioning driver or contention" wording; the analog drive levels
  themselves are not modeled.
- Setup/hold and electrical propagation are caller responsibilities. The
  AC tables (Table A/B/C: e.g. D→Y 19 ns, INTR→INTA 11 ns, reset setup
  15 ns/hold 2 ns, data setup 8 ns/hold 4 ns) and the Am29331A 15% speed
  grade are timing, not functional, contracts and are outside this model.

Figure 3 constructs (FOR/END FOR, REPEAT/UNTIL, WHILE/END WHILE, CASE via
PUSH D + GOTO M, nested IF with PUSH D C) and the Figures 4–7 interrupt
and trap cycles validate documented behavior; no speculative instructions
or system-specific decoders are introduced.
