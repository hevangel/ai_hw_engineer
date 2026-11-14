# Am29331 implementation plan

1. Transcribe manufacturer Tables 1 and 2 into
   `references/instructions.csv` before RTL, one row per opcode,
   condition pass/fail and counter-qualifier, with address source, stack
   action, counter action, comparator action and D-mux selected
   independently. Check the transcription against both the 1988 final
   datasheet and the 1985 advanced-information handbook page images.
2. Implement one native-pin module: interrupt multiplexer into the address
   register, modulo-64 pointer over the 33-word stack, deferred interrupt
   push, FC/C̄IN trap select, HOLD freeze, master/slave ERROR comparison.
   Model bidirectional pins as input/output/enable triples.
3. Generate transition expectations from the external CSV through the
   independent Python interpreter (no RTL parsing), covering every opcode
   across condition polarity, carry-in, force-continue, output-enable,
   counter boundaries, stack depths, interrupts, reset and hold, plus
   random exploration of the full input and state space.
4. Observe all state through native pins only: PC with the FC/C̄IN stall,
   SP and stack words through POP D with OED, counter through PUSH C then
   POP D, interrupt returns through the stack.
5. Run the original Figure 3 microcode constructs and the Figures 4–7
   interrupt and trap flows with exact executed and next addresses,
   unmapped execution fatal; exercise the 33-entry envelope including the
   documented single-wrap overflow; verify master contention and slave
   mismatch through ERROR.
6. Prove lint-clean, BMC/PDR/cover formal, simulation, synthesis/check;
   record actual results and limits; update the chip index and the series
   card.
