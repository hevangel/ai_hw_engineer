# AMD Am9080 / Am9080A: eight-bit microprocessor

**First introduced: 1975*** (dated public availability evidence for Am9080A).
AMD advertises the CPU and support family in [October 16, 1975 Electronics](https://www.worldradiohistory.com/Archive-Electronics/70s/75/Electronics-1975-10-16.pdf)
and [October 25, 1975 Electronic Design](https://www.worldradiohistory.com/Archive-Electronic-Design/1975/Electronic-Design-V23-N22-1975-1025.pdf).
The exact first shipment and earlier unsuffixed revision's chronology are not
established here. The implemented contract is the documented Am9080A.

AMD's first conventional CPU brought it into eight-bit computing before x86.
It ran the 8080 instruction set and used the same memory/I/O architecture,
while retaining meaningful differences from Intel silicon: AMD ANA/ANI clears
auxiliary carry. The manufacturer's handbook and independent physical-chip
testing agree on that difference.

All 244 documented instructions are implemented and checked against an
immutable external oracle. The complete flow passes historical software,
exhaustive ALU/opcode regressions, UVM, formal proof/cover, lint and synthesis.
The implementation uses a functional ready/valid memory/I/O bus;
original two-phase electrical timing and pin waveforms are outside its scope.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Independent oracle/software provenance](references/README.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

```sh
sh design/amd_am9080/scripts/run_all.sh
```
