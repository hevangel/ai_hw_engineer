# 74181 library migration verification

Date: 2026-10-20

## Change

The complete tracked `design/alu_74181/` design was moved into
`design/ttl_74xx/`. Its previous README is `README_74181.md`; the library README
records the implemented inventory and pending expansion scope. Active index,
Surfer documentation, and example paths now point to the shared folder.

The RTL module name, ports, equations, formal properties and independent reference
models are preserved. One long testbench diagnostic was split into concatenated
strings to satisfy the current Verible line-length rule. Existing chip-specific
scripts now use the `run_74181_` prefix. Aggregate scripts provide the standard
library entry points and currently execute this implemented chip only. Script
composition uses `sh` so execution does not depend on Windows checkout mode bits.

## Reproduction

```sh
docker run --rm -v "${PWD}:/workspace" -w /workspace \
  ai-hw-engineer:latest sh design/ttl_74xx/scripts/run_all.sh
```

## Results

| Check | Result |
|---|---|
| Verilator 5.052 strict RTL and exhaustive bench lint | PASS |
| Verible authored-source lint, including UVM package | PASS |
| xezim exhaustive simulation | PASS: 16,384 vectors, 81,920 field checks, zero failures |
| xezim UVM all-mode simulation | PASS: 64 transactions, zero UVM errors/fatals |
| SymbiYosys BMC | PASS |
| SymbiYosys unbounded proof | PASS |
| SymbiYosys cover / non-vacuity | PASS |
| Yosys 0.69 generic synthesis | PASS: 82 cells; zero structural problems |

The image reports a UVM library phase-delay warning; it did not prevent the
64-transaction regression from finishing. Original historical reports remain
available, and this report records the migration rerun separately.

## Subsequent library expansion

This report records the initial migration-only stage. The user subsequently approved
classic 7400-74299 digital functions; the expanded inventory and current results
are recorded in [the library report](library_report.md).
