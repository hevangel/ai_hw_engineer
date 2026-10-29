# Library test plan

Inventory integrity is checked before every aggregate run: exactly 296 entries,
289 implemented functions, seven authorized exclusions, no duplicate modules,
one matching module per source file, no missing specification/test, and no TODOs.

Every part receives strict `verilator --lint-only -Wall`, a four-state xezim
regression requiring its explicit PASS marker, and Yosys elaboration/proc/flatten/
optimization with `check -assert`. Failed commands or absent PASS markers fail
the run; logs and source fingerprints are retained per phase in `work/library/`.

The test suite combines imported tests with independent manufacturer-table cases:
strobe/expander settings, all 7485 cascade combinations, both edges of ripple
counters, 7474 simultaneous async controls, 256 native 74165/166 load patterns,
74279 secondary set inputs, all 74299 load/shift/output modes, read-only ROM image
decoding for every address, every RAM address over three patterns, write-enable/
chip-select protection and FIFO full/empty/wraparound/mixed operations.

RAM/FIFO checks validate their documented normalized interfaces. Tests do not
assume deterministic contents for uninitialized storage. ROM test fixtures are
synthetic and do not claim to reproduce any manufacturer character mask.
Targeted formal checks and the independent original 74181 exhaustive/UVM flow
supplement this suite; see `library_formal_plan.md` for proof limits.
