# Implementation plan

1. Review dated manufacturer evidence and the independent references;
   record their disagreements before RTL
   ([source review](../../../plans/mos_vicii_source_review.md)).
2. Compile the pinned MAME VIC-II unchanged against minimal framework
   stubs; expose fetch order, pixel stream and line levels per clock.
3. Implement the dot-clock RTL for five variants in one module, mapping
   the reference's cycle logic onto the cycle edge and its lazy dot drawing
   onto the following eight dot edges, including per-field write
   visibility, collision lag and process traits.
4. Compare every system clock and every pixel for all variants under
   KERNAL-like screens, all eight modes, random register programs, both
   character-ROM windows, light-pen pulses, per-line register changes,
   continuous collisions with IRQ acknowledgement and sprite crunching.
   Seed defects and require each to be detected.
5. Prove sequencer, write-pipeline and bus-control invariants with
   reachable covers; replay oracle-checked dots in both SV simulators;
   synthesize every variant.
6. Integrate with the 6510, two 6526s, SID, PLA and ROMs and run original
   C64 firmware and software with independently checked screens before
   VIC-II sign-off (part of the Commodore 64 system build).

Steps 1-5 are this milestone; step 6 remains open.
