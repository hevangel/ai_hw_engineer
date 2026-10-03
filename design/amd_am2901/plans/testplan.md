# Test plan

Use the pinned external Am2900ME source for results, source selection,
destinations and shift outputs. Initialize through actual chip writes; compare
both pre-write outputs and post-cycle visible RAM/Q, including aliased addresses.
Check every 512-word encoding, both carry inputs, every R/S pair for all source
and ALU modes, OE release, shift input/output enables, and unchanged registers.

Dedicated directed native-phase tests must change addresses/direct data while
CP is high and low and distinguish transparent storage from edge-only behavior.
Historical Figure 21 signed-multiplication microcode must execute on cascaded
eight-bit and sixteen-bit datapaths with
explicit external control signals and exact microstore/next-word checks.
Compare cascaded arithmetic against full-word mathematics. Poison unused
microstore positions; never use padding to tolerate wrong next addresses.

Reject simulation fatals even if a simulator returns zero. Record external
oracle discrepancies and manufacturer-backed adapter corrections separately.
