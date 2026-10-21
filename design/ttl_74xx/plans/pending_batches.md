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

## Original register and diagnostic interfaces

Review MMI 1984 LS793/794 readback and National 1981 LS952 control tables alongside
Fairchild 1987 AC818 diagnostic diagrams. Preserve feedback when a readback port
is driving, positive-edge versus transparent storage, independent diagnostic and
pipeline clocks, registered diagnostic-port enable, and externally resolved Y
feedback. For the LS952 test input-disable/output-disable priority, OR-combined
up-transfer, parallel-down/serial-shift priority, synchronous two-rank clear,
serial order and all control combinations using source-derived transitions.
Native asynchronous output enables remain live while storage operates.

## Native incident-wave bus interface (16246)

Review TI SCBS227J table and diagram before implementation. Preserve eight
simultaneous split-path channels and three individual direction controls; model
open-collector release using per-pin drive flags. Exhaust control combinations,
all input bits and external feedback observations, then run strict lint, simulation
and complete generic synthesis. Analog keepers remain a documented board-level
assumption.

## Native four-clock registered transceiver (16470)

Review the TI SCBS085E table and actual gated-clock diagram before RTL. Retain
CLKEN's output-isolation effect as well as capture gating. Test four independent
clocks, byte enables, capture with OE disabled, output hold and legal CLKEN
transitions, then run strict lint, simulation and complete generic synthesis.

## Native octal feedback transceivers (1620..1623, 2620)

Review TI 1984 Volume 3 tables, inversion/output-type list and feedback prose.
Preserve independent GBA/GAB enables and qualified bus latch behavior. Model
feedback only after a settled directional transfer with no competing external
drivers. Test every byte, both directions, feedback hold and isolation, then
strict lint, simulation and complete generic synthesis.

## Pure-digital clock fanout (807, 3807, 2525)

Review manufacturer block diagrams and pinouts. Preserve the complete fanout
without fabricated enables or clock division. Test both steady logic levels and
transitions, then strict lint, simulation and generic synthesis. Omit analog skew,
hysteresis and electrical drive. The 2526 remains pending until its selector
polarity is established by a source beyond the advance-information pin list.

## Externally clocked digital 4060 divider

Review TI SCLS161D falling-edge table and oscillator-gate diagram. Expose only
native divider taps and two oscillator buffer outputs; no RC timing model.
Verify complete counter periods, tap mapping, both reset phases and wrong-edge
hold, then strict lint, simulation and generic synthesis.
