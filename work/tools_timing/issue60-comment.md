## P1 (per-part TTL delays) implemented in #94

`board/timing.json` now carries typical and maximum propagation delays for every
modelled package, each with the manufacturer document and printed page. The
generator refuses to emit a characterized part without a source, so a guess
cannot enter the board. `generate_rev0.py --timing typ|max` regenerates the same
netlist from that table; `--timing legacy` still reproduces the checked-in board
byte for byte and remains the default.

Measured (Icarus 12.0-3, same authored CPU and unmodified Monitor ROM):

| Timing set | Directed socket test | Monitor keyboard/CPU | Monitor frame comparison |
|---|---|---|---|
| legacy (5 ns) | pass | pass, 64,393 instructions, 4,516 unresolved reads | pass, pixel-exact |
| datasheet typical | pass | pass, 64,394 instructions, 4,516 unresolved reads | rejected: capture one sample out of phase |
| datasheet maximum | fail: RAM row 0 read xx | pass, 64,394 instructions, 4,516 unresolved reads | not compared by the gate |

Two things P1 predicted are confirmed rather than assumed:

* the Monitor deposit/examine path survives published worst-case TTL delays,
  with the instruction count moving by one against the legacy run;
* the maximum-delay socket failure is a harness artifact, not a board finding —
  `tb_rev0_wiring.sv` drives address/data at the phi0 edge with fixed waits, so
  it encodes the zero-delay phase relationship it is supposed to test.

Still open and stated in the report: the socket stimulus needs phase-correct
setup before its maximum result means anything, and the boot capture samples
10 ns after the pixel clock (shorter than a 74LS74 clock-to-Q), so the frame
comparison holds only for the legacy model.

P2/P3 are untouched: the DRAM/ROM models are marked `idealized` and keep the
legacy delay, because they carry no access-time or refresh behaviour. The
datasheet values are already in the table for that rework.
