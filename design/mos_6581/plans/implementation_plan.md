# Implementation plan

1. Review the dated register description and the independent references;
   record their disagreements before RTL
   ([source review](../../../plans/mos_sid_source_review.md)).
2. Build the unchanged reSIDfp engine as a test-only oracle; observe
   per-cycle waveform outputs, envelope counters, reads and the noise
   shifter; refresh its sync schedule every clock.
3. Implement the digital core for both models in one module, with the
   combined-waveform pull-down as an external combinational table port.
4. Compare every clock for both models: every waveform combination with
   ring/sync/gate, random programs with dense register traffic, test-bit
   holds through the shift-register reset and fade, floating-DAC fade,
   sync/ring chains, every ADSR rate with attack/release completion, and
   gate toggles at every envelope-pipeline phase. Seed defects and require
   detection. Prove structural invariants; replay oracle-checked clocks in
   both SV simulators; synthesize both models.
5. Analog stage: a sampled DAC/filter/mixer model compared with reSIDfp's
   audio output under explicit error bounds, kept separate from the
   digital sign-off.
6. Original C64 music software on the integrated system with independently
   checked output, then hardware captures.

Steps 1-4 are this milestone; steps 5-6 remain open.
