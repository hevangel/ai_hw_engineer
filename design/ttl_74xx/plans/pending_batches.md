# Pending 74-series implementation batches

The user requested continuation on 2026-10-21. Keep every pending digital part in
scope. Implement from manufacturer tables, not catalog descriptions or substituted
generic functions. Record source URL, SHA-256 and table pages for each new model.

The first batch adds native logical controls for universal bus drivers and DDR
DIMM registered buffers. Review latch-enable polarity separately for each function;
retain independent transceiver directions and clock enables. Three-state outputs
use explicit drive masks. Differential clock receivers accept a normalized digital
clock representing the valid complementary crossing; voltages and analog skew are
outside the user-requested scope.

Specs precede RTL. Tests exercise both edges, transparency at both clock levels,
hold, disabled outputs while storage operates, and asynchronous reset dominance.
Run strict lint, simulation and full generic synthesis for every added part, plus
independent formal contracts and covers where applicable. Refresh the public index
and report without hiding remaining work or treating subset verification as completion.

## Additional independent formal checks

Universal drivers are proved with native opposite LE polarities, both storage and
transparent modes, arbitrary data and output enables, with enabled/disabled covers.
The 7416213 passive switch is proved for all select states from a separately
transcribed component-label table, arbitrary strong drivers/data and conflict
resolution. Covers reach three-way transfer, three-way conflict and full isolation.
Formal results carry source/configuration fingerprints, and the report rejects
stale successes or missing check/cover tasks.

## Source-reviewed bus and counter batches

Passive-switch models resolve connectivity in both directions from explicit
external strong-driver samples. Test references build connected components from
direct edges, independently of the RTL topology constants. Exercise every select
state, reverse transfer, floating nets, conflicting drivers and weak precharge or
pulldown overridden by a strong driver. Dedicated keepers capture the last valid
external drive and retain it weakly after release.

Wide registered transceivers retain independent bank clocks/directions/enables and
real-time versus stored selections. GTL translators retain mixed channel directions,
open-drain release and auxiliary enable/feedback controls. Supply-monitor decoders
use a classified digital supply input while retaining asynchronous decoder controls.
The 4059 must test native preset partitioning, decimal-weighted section presets,
all divide modes, one-cycle pulses and stopped-clock asynchronous LE release.
Logical asynchronous controls remain required when propagation delay is omitted.
