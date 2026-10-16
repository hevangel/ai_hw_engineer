# Intel 8087 implementation plan

1. Cache and inspect the July 1980 Intel supplement; establish the original
   control word, data formats, instruction encodings and exception rules.
2. Implement integer-only temporary-real arithmetic and memory conversions.
3. Implement stack, tags, original ESC decode, control state, memory sequencing,
   environment save/restore and exception retirement.
4. Add independent numerical oracle tests, original Intel software regressions,
   protocol stalls and bounded formal control-state checks.
5. Run formal before simulation, strict lint and Yosys synthesis. Record exact
   supported behavior, evidence, unresolved gaps and interface limitations.

The architectural core is the first integration boundary. A native-pin adapter
is a separate deliverable and must not be implied by a functional core result.
