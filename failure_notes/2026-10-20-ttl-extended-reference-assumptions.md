# Extended TTL reference models shared their test assumptions

## What exposed the defects

During extension above 74299, manufacturer review found that the inherited
74390/74393 models counted on rising edges, and the supplied minimal tests
completed a full low-high-low clock cycle without checking the intermediate
edge. TI's [SN74LS390](https://www.ti.com/lit/ds/symlink/sn74ls390.pdf) and
[SN74HC393](https://www.ti.com/lit/ds/symlink/sn74hc393.pdf) counter diagrams and
function descriptions identify falling-edge counting. The imported tests' pass
claims did not demonstrate the physical edge.

Independent code review also found writable ROMs/PROMs, disabled OC banks driving
zero instead of releasing, and a 74311 RAM model with no output latch. These
were reference-baseline defects detected before the extended models were committed.
They are recorded because outside-suite review, rather than the supplied tests,
exposed shared assumptions. FIFO wrap, missing package dependency and EDAC faults
caught by new local tests are ordinary precommit failures, not escaped local defects.

## Root cause

Tests and RTL repeated the same simplified interface assumptions. Completing a
clock cycle hides which edge updated state; a single enabled data value misses
release semantics; testing writes on a ROM confirms an incorrect abstraction.
An upstream 'complete' label and its tool pass claims were not independent oracles.

## Fix and prevention

- Check both counter edges, both independent counters and asynchronous clear.
- Verify all data/enable combinations on the corrected OC driver banks; represent
  release by logical one and document wired-AND board resolution.
- Replace ROM writes with INIT_FILE-backed immutable arrays and nontrivial
  every-address test fixtures. Require an explicit 74311 output latch contract.
- Verify separate shift/storage clocks, clear preserving output storage and
  disabled output behavior on all byte values for the 74595/596/599 regressions.
- Reject generic placeholders and JTAG models which omit digital boundary scan.
- Record source-backed native behavior separately from normalized assumptions.
  Missing digital devices stay pending and make the full completion gate fail.

Every included part is rerun through strict Verilator lint, xezim simulation and
Yosys synthesis. Large memories preserve inferred memory cells in the coarse
synthesis stage. Targeted formal proofs include the 74574 register/drive contract
and reachable enabled/disabled states; no blanket all-part conformance is claimed.
See the [current verification report](../design/ttl_74xx/report/extended_report.md)
for actual tool outcomes and remaining work.
