# Intel 8273 coverage report

Measured on 2026-10-03 with Xezim 0.11.0, after the final RTL regression passed.
`scripts/run_coverage.sh` instruments `tb_top.dut`, including its serial and DPLL
helpers, runs the directed suite with seed 1 and summarizes the actual database.
There are no coverage exclusions or manually adjusted totals.

| RTL metric | Covered / total | Coverage |
| --- | --- | --- |
| Statements | 520 / 552 | 94.20% |
| Branches | 274 / 321 | 85.36% |
| Toggles | 1,366 / 1,660 | 82.29% |

These numbers cover this instrumented directed run only. The separately executed
maximum-length, DMA-link, DPLL-sweep and UVM tests are not merged into these RTL
totals. Thus the percentages do not describe all verification stimulus, and
uncovered statements, branches and bit transitions remain. They are not waived.

The directed suite checks exact transmit bits and receive byte/result ordering
using 44 independent body vectors, good/corrupt FCS, NRZ/NRZI and buffered/
unbuffered transfers. Other directed checks cover filtering, non-DMA service,
stretched strobes, DACK without chip select, modem loss, overruns, length limits,
early/final results, preframe sync, transparent data, abort variants, EOP and
loop turnaround. See the [test plan](../plans/testplan.md).

## UVM functional coverage

The dedicated UVM collector's `command_cg` recorded 54 command samples and hit
all six explicitly defined bins (100% of that small coverpoint):

| Command | Samples |
| --- | --- |
| 91: set operating mode | 12 |
| A0: set serial mode | 6 |
| C0: general receive | 8 |
| C8: transmit frame | 4 |
| 22: read port A | 12 |
| 23: read port B | 12 |

This coverpoint is intentionally limited to the UVM scenario's commands. It
does not claim coverage of every opcode, parameter combination, result or
protocol corner case. UVM's scoreboard checked 628 actual observations with no
errors or fatals. The larger directed suite and integration tests supply the
remaining verification described in the [final report](final_report.md).

## Formal reachability

Separate post-reset covers reached normal Tx completion at step 68, successful
supervisory-frame Rx at step 66 and carrier-loss error at step 18. The covers
demonstrate reachable exercised paths; they are not functional coverage closure.

Reproduce with `sh design/intel_8273/scripts/run_all.sh`. RTL coverage is written
to `work/coverage/rtl.json`; UVM bins are in `work/uvm/coverage.json`. Generated
databases and traces are ignored by Git.
