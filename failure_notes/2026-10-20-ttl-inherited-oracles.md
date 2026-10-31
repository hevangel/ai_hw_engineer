# 2026-10-20 — inherited TTL shared-oracle blind spots

## Observation and external oracle

During the first integration audit of the pinned MIT `sn74xx_sv` baseline,
manufacturer data disagreed with models that passed their supplied tests.
TI's [1985 TTL Data Book volume 2](https://archive.org/details/bitsavers_tidataBookVol2_45945352)
shows the 7423/7425 strobe-low output is high (page 3-123); the baseline RTL
and its test both forced it low. The 7490/92/93 devices count on falling clock
edges, while the supplied models/tests counted rising edges. The native 74165
parallel load is asynchronous. Several catalogue entries identified as ROM/PROM
had a generic writable-RAM implementation and matching write/read tests.
The [74297 datasheet](https://www.ti.com/lit/gpn/sn74ls297) also exposes three
functional blocks absent from the baseline's generic eight-bit filter.

These are inherited verification blind spots found before this repository's
first library sign-off. No pre-existing board integration is claimed affected.

## Cause

Passing tests reproduced the same assumptions as the implementation. An exhaustive
strobe test still checked the wrong truth table. Short memory smoke tests did not
cross-check device type, pin function, capacity, or address coverage. Prior tool
pass labels therefore did not establish manufacturer-semantic agreement.

## Correction and validation

The library preserves manufacturer-linked contracts and the exact source/license
revision. Local corrections fix strobe polarity, counter edge/state tables,
asynchronous 74165 load and bit order, and read-only image-backed ROM interfaces.
The 74297 is a documented sampled digital K-counter/I-D/phase-detector model.
The existing independently verified 74181 remains authoritative; the simplified
imported ALU is not used. Normalized interfaces and native pin differences are
explicit in the library overview and per-part specifications.

Validation includes strict lint, full generic synthesis, four-state tests,
independent truth-table formal checks, both-edge counter tests, all-address RAM
and loaded-ROM checks, FIFO ordering/boundary/wraparound tests and the preserved
74181 exhaustive/UVM/prove/cover regression. Actual current results are recorded
in the [library report](../design/ttl_74xx/report/library_report.md).

## Prevention

- A frozen inventory distinguishes real functions, family differences and exclusions.
- A passing imported suite is evidence of execution, not a manufacturer oracle.
- Specs must identify normalized controls, unspecified storage contents and native
  interface limits before a board uses the module.
- Test both edge polarities, every address, enabled/disabled outputs and simultaneous
  asynchronous controls; preserve an independent table source for semantic fixes.
- The aggregate runner fails on missing tests, failures, absent PASS markers and
  stale source fingerprints. Formal families include cover/non-vacuity checks.
