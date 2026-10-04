# Am2911 oracle and historical microprogram provenance

The manufacturer explicitly defines Am2911 as the common sequencer with
R and D internally connected and OR pins removed (Figure 2 / PDF 84).
The independently sourced Figure 6 transition table therefore applies,
with the enabled register taking D and no OR contribution to the address.
The verification reference uses a top-first rotating list, while the shared
RTL engine uses a circular memory and pointer. It does not read DUT internals.

Actual original manufacturer Figures 7/8 subroutine control sequences are
executed on three Am2911 slices. Literal executed/fetched address lists are
independent of the state model and include a one-instruction nested routine.
All unused microstore positions are POISON. The final published fetch ends
the trace without executing an additional invented routine. The fixtures
instantiate symbolic addresses in two placements, including nibble boundaries.

These are the original published microprogram sequence artifacts, not a
recovered complete computer ROM. Their exact settings and transcription
boundary are documented in the [common provenance](../../amd_am2909/references/README.md).
Initialization uses actual ZERO/register loads and four pushes; no internal
force, invented reset, initial-pointer assumption or tolerant padding is used.

Primary source: [AMD 1978 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
PDF 84/86/87/94/95; hash in the [shared cache manifest](../../../references/amd/README.md).
