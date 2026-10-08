# Intel 8080: eight-bit microprocessor

**First introduced: 1974.** Intel's [manufacturer
history](https://www.intel.com/content/www/us/en/newsroom/news/50-years-ago-the-influential-intel-8080.html)
dates its launch to 1974. Month-level accounts distinguish announcement and
release; this entry makes only the supported year-level claim.

The 8080 powered the MITS Altair 8800 and helped establish general-purpose
microcomputing. Its wider address space and external stack removed major
8008 constraints; its software architecture also influenced later Intel
processors. These historical connections are described in Intel's history.

This design starts with the repository's verified Am9080 controller and
adapts the ALU and independent verification to Intel behavior. The target is
all 244 documented opcodes with a functional ready/valid memory/I/O bus,
including interrupts, HOLD and HALT. Native pin timing and undocumented
aliases are later milestones. ANA/ANI uses Intel's operand-dependent AC,
which differs from both AMD Am9080 and Intel 8085.

The initial functional suite passes lint, formal proof/cover, exhaustive ALU
and opcode regressions, original historical diagnostics, UVM and synthesis.
Observed counts and tool warnings are recorded in the report below.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Primary sources, independent oracle and software provenance](references/README.md)
- [Verification report and remaining work](report/final_report.md)

Run in the project's hardware-tool environment:

```sh
sh design/intel_8080/scripts/run_all.sh
```
