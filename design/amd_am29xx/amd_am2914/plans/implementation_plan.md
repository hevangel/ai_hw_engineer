# Implementation and verification plan

1. Transcribe all16 primary instruction effects before RTL; retain the original
   interrupt procedure in Figure4/PDF177 as an application regression.
2. Build native pulse latches, clocked interrupt/mask/status/hold state, output
   buses, enable state and all cascade pins. Document digital edge adaptation
   and source interpretation explicitly in the assumption ledger.
3. Independently interpret manufacturer table artifacts for formal next-state
   and simulation checks; never derive the oracle by reading implementation.
   Prove latch capture/clear, LOW-phase sampling and rising-edge state changes,
   including IE inhibition; run non-vacuity covers.
4. Exhaust mask/request combinations, thresholds, per-mask operations and
   clear data. Exercise pulse retention versus bypass, held vector clearing,
   sticky overflow, enable/disable, sub-cycle changes and no-edge reads.
5. Execute the original save/read-vector/clear/service/restore procedure.
   Test eight actual controllers with an actual Am2913 using original ripple
   cascade wiring, including threshold transfer at every vector7 boundary,
   status reads, nested requests, highest-vector overflow and restoration.
6. Run lint, formal BMC/prove/cover, native simulation and synthesis/check;
   document actual results before adding a verified index/ledger entry.
