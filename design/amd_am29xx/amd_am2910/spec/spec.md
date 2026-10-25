# Am2910 digital specification

Primary contract: AMD 1978 Am2900 Family Data Book, printed 2-88–2-100
(PDF 96–108), visually inspected Table I/II on PDF 99 and Figure 4 on PDF 103.
All registers update on CP rising edges. There is no reset pin: instruction
JZ empties the stack and outputs zero; it does not clear the counter or RAM.

Twelve-bit D, Y, micro-PC, register/counter and five stack entries. Four-bit
instruction. CC_n low passes, CCEN_n high forces pass. CI high makes next
micro-PC Y+1 modulo 4096; low retains Y. RLD_n low overrides counter hold or
decrement with D at the edge, but does not change current-cycle branch tests.
OE_n high releases Y (separate y_oe output); internal execution continues.
PL_n is low except JMAP selects MAP_n low and CJV selects VECT_n low,
independently of condition. FULL_n is low at depth five.

## Instruction actions

The external table transcription in ../references/instructions.csv defines
all sixteen instructions by fail/pass and counter-zero branches. PUSH writes
the pre-edge micro-PC, which is the next sequential address in a pipeline.
At depth five another push overwrites the top without increasing depth.
Pop at zero leaves depth zero. Stack references while empty are unspecified.
Counter decrement occurs only for nonzero counter in RFCT/RPCT/TWB, even
when TWB passes and takes the sequential exit. RLD_n has highest load priority.

## Assumption ledger and scope

- ASSUMPTION: before JZ, depth is unknown. A three-bit RTL encoding models
  physical legal depths 0–5; formal constrains initial depth to this legal
  domain without initializing any state. Software starts with JZ.
- ASSUMPTION: empty-stack Y is unconstrained historically. RTL returns stored
  bottom-slot data; simulation masks Y/PC after such reads and establishes
  defined PC again by a direct jump. No defined empty-stack address is promised.
- Setup/hold and electrical propagation are caller responsibilities. This is
  edge-accurate digital behavior, not a gate-delay or bipolar electrical model.

Figure 4 firmware validates documented behavior; no speculative opcode
semantics or additional system instruction decoder are introduced.
