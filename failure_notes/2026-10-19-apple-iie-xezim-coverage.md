# Apple IIe board coverage-sensitive simulation failure

The uninstrumented xezim board bus regression passes main/aux RAM and ALTZP.
With only --code-coverage --code-coverage-scope tb_top.dut added, the same
first main-RAM read returns 00 instead of A5 at time 985000 in tb_top.access.
Verilator passes the same RTL and stimulus; its real-ROM run also supplies
independent line-coverage evidence. The failure appeared while adding board
coverage, before the platform was committed.

Root cause is not isolated: this observation is not proof of an xezim defect
or of a specific scheduling cause. The strict expected value is unchanged.
The board's reproduce_xezim_coverage.sh retains the failing configuration;
run_sim.sh retains the uninstrumented xezim functional gate. Coverage uses
Verilator's real-firmware line counters instead. MMU/IOU unit coverage keeps
its existing separate xezim flow. No full-system xezim coverage claim is made.

The system report records actual simulator/version outcomes. A future
instrumentation change must pass the existing strict RAM regression before
board xezim coverage can replace the independent coverage backend.

## Isolated asynchronous observation case

A separate minimal RAM probe writes 55 through a nonblocking clocked write.
xezim reports X for the asynchronous constant-address read, then 37 hex after
the read address is selected away and back. The stored value is correct;
its constant-address observation did not refresh. The same case passes in
Verilator. The strict reproduce_xezim_memory.sh retains this failure outside
acceptance. This isolates an observable language-level discrepancy; the
internal compiler mechanism and its relationship to coverage sensitivity
are not proven.

The original-ROM SystemVerilog gate now issues explicit read transactions
on the existing read-only debug port, matching the C++ driver's selected
reads. It still requires exactly 55 at physical main address 0300. It does
not alter RAM writes, ROM bytes, CPU behavior, or any expected value. This
was discovered by comparing the identical full ROM stimulus across engines,
then reducing the observation to a small independent RAM fixture.
