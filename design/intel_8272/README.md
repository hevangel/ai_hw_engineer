# Intel 8272A floppy disk controller

Synthesizable SystemVerilog recreation of the 8272A's command, DMA/non-DMA, seek and decoded-sector behavior, with separate IBM FM/MFM word encoding and CRC helpers. The core implements all 15 commands across four logical drives.

## Historical context

The 8272 family moved floppy transfers, sector addressing, seek timing and error reporting into a programmable controller. Its command/result protocol let a processor request CHRN sectors and use DMA or interrupts for data, rather than service individual encoded disk bits. The 8272A retained the earlier programming interface and changed VCO synchronization behavior; this made the family important to systems using IBM-compatible FM and MFM disk formats.

The index records **1980* for the 8272 family and 1982* for the 8272A**. These are the earliest dated manufacturer documents located for this design, not established first-shipment dates. An Intel 8272 sheet marked January 1980 appears in the [CompuPro Disk 1 technical manual](https://www.bitsavers.org/pdf/compupro/Storage/171_DISK1/171F_Disk_1_Technical_Manual_1982.pdf); the [Intel 8272A preliminary datasheet](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf), order 210806-001, carries ©1982. Exact commercial introduction dates remain uncertain.

## Integration boundary

This is a **virtual-drive functional core**. The host uses edge-qualified CS/RD/WR/DACK, A0, TC, split byte data, DRQ and IRQ. A media backend supplies actual sector IDs, read bytes, index events and CRC errors, and consumes write metadata/bytes. It must obey the unbackpressured byte-service contract in the specification. `us_tick` supplies emulated microseconds; seek and head timers use `MS_US=1000` by default.

The codec and CRC modules operate on individual IBM words/bytes. They do not connect the controller to a raw flux stream. A complete serial track parser/formatter, PLL, physical gaps, write precompensation, package electrical timing and actual floppy-drive or operating-system integration are outside this implementation. GPL is passed through the command protocol but gap generation belongs to the backend. Assumptions about compatible scan masking, event ordering and conflicting recalibration prose are explicitly recorded in the spec.

## Files and verification

* [Specification and assumption ledger](spec/spec.md)
* [Implementation plan](plans/implementation_plan.md)
* [Test plan](plans/testplan.md)
* [Formal plan](plans/formal_plan.md)
* [Verification report](report/final_report.md)
* [Coverage report](report/coverage_report.md)
* [Media integration guide](docs/media_interface.md)
* [Reference provenance](references/README.md)

Run inside the project Docker image:

```sh
sh design/intel_8272/scripts/run_all.sh
```

The flow runs strict RTL lint, bounded and unbounded safety checks, non-vacuous covers, directed and seeded tests in Verilator and Xezim, a UVM host scoreboard, independent codec/CRC vectors, measured RTL coverage and generic Yosys synthesis. Detailed claims and uncovered cases are recorded in the reports; passing this flow establishes the documented functional boundary.
