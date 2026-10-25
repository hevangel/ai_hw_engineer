# CIA timer foundation results

This report measures the isolated timer foundation. The assembled CIA and
its original-software qualification are measured in the
[integration report](integration_report.md) and [software report](software_report.md).

## Independent oracle

VICE revision `d928b850b7ef4c1b1826a6efd175d8eaa80344d8`, original
`ciatimer.c`, `ciatimer.h` and GPL license, fetched and SHA-256 checked by
`scripts/fetch_timer_reference.py`. External source stays under ignored
`work/reference/`; it is compiled unchanged, never translated from RTL.
The test-only adapter calls the public timer APIs in their documented
update-before-write order. Host stubs provide scalar clock types and store
alarm deadlines; snapshot functions abort if called. No timer arithmetic
or state transition is supplied by those stubs.

## Measured gates

Docker `ai-hw-engineer:latest`, Verilator 5.052, xezim 0.11.0,
Yosys/SymbiYosys 0.69.

| Script | Result |
|---|---|
| `run_timer_reference.sh` | Strict lint and 3,623,621 cycle comparisons, all 65,536 reload values, 1,083 underflows; registered counter/latch/start/underflow and pre-commit count/start/event views agree exactly |
| `run_timer_fourstate.sh` | 86,993 independently generated records pass xezim before and after state commit; the generator links only the unchanged external C oracle, with no RTL included |
| `run_timer_formal.sh` | BMC/PDR and six reachable covers pass, bound 24 |
| `run_timer_synth.sh` | Generic synthesis and `check` pass, 242 cells including current-cycle read outputs |

The cycle suite alternates one-shot/continuous operation across every load,
checks active pipeline stop/start, force loads, external steps, complete
underflows at zero and boundary counts through FFFF, then one million seeded
random boundary writes and steps. Random tests include writes on reload and
underflow; expected values are not altered to match the RTL.

Four-state replay includes every 8-bit low reload through underflow and
50,000 seeded random records. Text inputs are copied to the container's
temporary filesystem before streaming; character-oriented reads over a
Windows bind mount were slow. That affects test I/O, not expected values.

## Remaining requirements

The isolated timer's cycle boundary is explicit. Eleven unchanged Lorenz
programs now check the assembled PHI2 interface, cascade, PB outputs and
old-CIA IRQ/NMI-sensitive behavior in the documented original-KERNAL
fixture. VICE is an emulator rather than a physical capture. Remaining
subcycle, serial synchronizer, timer-B/read-loss and revision evidence is
tracked separately in the [specification](../spec/spec.md).
