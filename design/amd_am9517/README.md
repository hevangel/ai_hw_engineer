# AMD Am9517 multimode DMA controller

Four independent channels transfer data between memory and peripherals, with
fixed/rotating arbitration, several service modes, automatic reload, memory
copy/fill and cascade expansion. It lets an eight-bit CPU delegate bulk transfers
and provides the foundation for the familiar compatible DMA programming model.

First documented: **by 1978**, public manufacturer announcement. AMD calls
the Am9517 new in its advertisement in the January 19, 1978 issue of
[Electronics](https://www.worldradiohistory.com/Archive-Electronics/70s/78/Electronics-1978-01-19.pdf),
PDF77–78. This is announcement evidence, not an asserted exact first-shipment
date; an earlier introduction has not been established.
**Verified functional reconstruction.** The complete lint, formal, native/UVM,
original-firmware, actual cascade, coverage and synthesis flow passes. Original
AMD semantics were audited against manufacturer documentation before adapting
the project-owned Intel 8237A starting point. The independent module implements
the original AMD differences and retains explicit timing/silicon assumptions.

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Validation report](report/final_report.md)
- [Coverage report](report/coverage_report.md)
- [Source and reuse assessment](references/README.md)
- [Original STUP/SDMA firmware](references/original_firmware.md)
- [AMD primary-source manifest](../../references/amd/README.md)

Primary source: [1979 AMD Designer's Guide](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf),
PDF245–260 and297–316. Original AMD software appears on PDF311–314.

Run `sh design/amd_am9517/scripts/run_all.sh` inside `ai-hw-engineer:latest`.
The flow includes formal, Verilator/xezim simulation, UVM, original manufacturer
software on Am9080A, an actual two-controller cascade, code coverage and Yosys
synthesis. The CPU fixture uses the existing pinned external 8080 ISS.
