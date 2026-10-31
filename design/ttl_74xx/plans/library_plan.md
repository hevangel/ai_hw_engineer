# Classic 7400–74299 implementation plan

This records the first completed range milestone. The subsequent
[extension plan](extended_plan.md) and [current coverage report](../report/extended_report.md)
govern numbers above 74299; the full expanded catalog remains incomplete.

## Original approved scope

The user approved all classic 7400–74299 digital functions on 2026-10-20, excluding
analog and timing-only variants. Freeze the 296-entry inventory in `manifest.json`:
289 digital functions, seven explicit exclusions, and no modules for missing numbers.

## Implementation

1. Move the existing 74181 into the shared folder and retain its public interface,
   source equations, independent oracle, datasheets and verification environment.
2. Record per-part specifications and manufacturer links before importing the
   pinned MIT functional baseline. Keep copyright, licensing and revision provenance.
3. Preserve distinct functions behind different family designations. Use a flat
   `src/` with one module per file; interfaces are documented functional contracts.
4. Correct the baseline defects found by strict tools and manufacturer table review.
   Expose digital expander and drive controls, correct edges and bit order, implement
   read-only ROM interfaces, and replace the generic substitute digital PLL filter.
5. Verify every model with strict RTL lint, self-checking simulation and Yosys.
   Add all-address RAM, image-loaded ROM, FIFO boundary/wraparound, asynchronous
   load/control and serial-chain tests. Add independent formal table and transition
   contracts with cover/non-vacuity. Retain the full original 74181 regression.
6. Publish the inventory, historical uncertainty, normalized-interface boundaries,
   reproduction commands and actual verification results in the shared README/report.

## Interface boundary

This milestone implements the normalized digital functions documented per part.
It does not certify native package-pin equivalence for every device. Specific
functional adapters for RAM/FIFO/multi-clock parts, accumulator pulse distribution,
ROM masks and the sampled 74297 are explicitly documented. Native asynchronous
board-pin integration would require a separate datasheet and integration review;
do not silently substitute a normalized interface in an existing board netlist.
