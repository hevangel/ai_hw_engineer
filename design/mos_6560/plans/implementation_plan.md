# Implementation plan

1. Establish primary-source register contract, dated history bound and
   assumption ledger before RTL. Implement the shared register block;
   exhaustively test chip addresses, mirror writes, dynamic readbacks,
   phase/read qualification and reset. Prove storage/drive invariants and
   reachable read/write covers, then synthesize.
2. Implement raster separately for 6560 and 6561, including NTSC offset,
   partial-line and interlace behavior. Compare unchanged independent
   source traces with pinned provenance, not a golden model copied from RTL.
3. Implement physical PHI1 fetch transactions, matrix/character/color
   sequencing and pixel output. Verify addresses as well as images against
   independent traces. Integrate phase-two register access.
4. Implement and independently qualify tones/noise/amplitude, POT timing,
   light-pen capture and actual mask-option pin behavior. Separate digital
   evidence from analog approximations and electrical validation.
5. Run original VIC-20 software on the native CPU and VIA combination,
   exact PC checkpoints and independently checked display/audio. Resolve
   assumptions before chip sign-off. Retain all four requested systems
   and the wider catalog in the series ledger.

Step 1 is a bounded component milestone; it does not complete the VIC.
