# Functional Coverage Report: intel_4002

Generated: 2026-08-28

Source: one self-checking xezim run (directed + fixed-seed random) and the
SymbiYosys cover task.

## Enumeration achieved

| Dimension | Coverage |
|---|---|
| Main-memory cells written + read back, DUT1 (chip 1, bank 0) | 64/64 (all 4 registers x 16 characters) |
| Main-memory cells written + read back, DUT2 (chip 2, bank 3) | 64/64 |
| Status characters written + read, both banks | 16/16 (4 registers x WR0-WR3/RD0-RD3 each) |
| Commands executed and observed selected | 13/13 (WRM, WMP, WR0-WR3, SBM, RDM, ADM, RD0-RD3) |
| Ignored ROM-side encodings exercised | WRR, WPM, RDR (no 4002 state change, no drive) |
| Chip numbers addressed on an active bank | 0, 1, 2, 3 (only the wired chip responds) |
| CM-RAM bank lines exercised | 0 and 3 with chips wired; 1 and 2 deselect (no chip wired) |
| Variants | 4002-1 (`Variant1=1`, `po_i`=1 -> chip 1) and 4002-2 (`Variant1=0`, `po_i`=0 -> chip 2) |
| WMP port paths | write, overwrite (5 -> A -> 0), per-chip isolation, reset clear, post-reset write |
| Reset | power-on and mid-operation (port + array cleared, chip fully functional after) |
| ADM/SBM | memory nibble driven unchanged; TB-side CPU arithmetic sanity check (SBM of 0xC -> 4, borrow out) |
| Random phase | 400 LFSR-driven cycles (fixed seed 16'hace1): DCL/SRC/commands/data against the golden model, both DUTs |

Code-coverage collection is intentionally not used; the per-command/per-cell
check matrix above plus the formal cover set are the coverage evidence
(per `plans/testplan.md`).

## Formal reachability covers

All 37 labeled reachability goals in `formal/intel_4002_cover.sv` are
reached by the SymbiYosys cover task (smtbmc --unroll z3, depth 30):
37 reached, 0 unreached. Deepest witnesses are the SRC -> write -> read
roundtrips at step 19. See `report/final_report.md` for the recorded
result and `plans/formal_plan.md` for the cover-engine decomposition.

## Result

```
TEST PASSED: 22297 checks, 1048 cycles
```
