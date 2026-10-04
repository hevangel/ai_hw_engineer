# Implementation plan

1. Preserve the original 1024x1 organization and absence of clock/reset.
2. Infer one latch per bit in a 32x32 organization, enabled only by normal-
   supply selected writing. Banking bounds both synthesis lowering and
   event-driven simulator cost while preserving every address's behavior.
3. Decode non-inverted asynchronous read and selected-write feedthrough from
   manufacturer switching waveforms, exposing data plus tri-state enable.
4. Represent retained-power standby explicitly as supply metadata; mask its
   undocumented selected output mode rather than inventing a guaranteed level.
5. Verify address isolation, transparent writes, deselected write protection,
   complete memory patterns, retained standby and two-chip bus banking.
6. Run lint, BMC, unbounded proof, reachable covers, simulation and synthesis;
   document observed results and dated primary historical evidence.
