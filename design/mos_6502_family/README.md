# MOS 6502 CPU family and package variants

Canonical issue: [#33](https://github.com/hevangel/ai_engineer/issues/33). One family folder and one public timeline card; one native sub-issue per identified physical chip.

| Chip | Member issue | Implementation / sourced history |
| --- | --- | --- |
| MOS 6502 | [#267](https://github.com/hevangel/ai_engineer/issues/267) | [mos_6502](mos_6502/README.md), [cycle](mos_6502/cycle/README.md) |
| MOS 6507 | [#268](https://github.com/hevangel/ai_engineer/issues/268) | Planned; no tracked implementation found |
| MOS 6510 | [#269](https://github.com/hevangel/ai_engineer/issues/269) | Planned; no tracked implementation found |

Historical dates, source qualifications and verification limits remain in member READMEs and the [design index](../README.md). Different RTL models of one chip share its member issue. Shared Apple II package models are linked from their member profiles; no RTL is duplicated. A family grouping does not imply pin compatibility or common motherboard use. Generic/unknown parts remain explicit inventory gaps.

## Model split

`mos_6502` (functional bus, one transfer per clock) and `mos_6502/cycle`
(physical bus, NMOS cycle behaviour) are independent implementations of the
same chip. They share the member issue and the same external oracles — py65,
the Klaus functional test and SingleStepTests vectors — but **no verification
result is transferred between them**, so a decode or ALU defect can exist in
one and not the other.

Decision: both stay. The cycle core is required for pin-level board models and
is the only one the Apple II board proves. The KIM-1 boot bench in
[`design/mos_6530`](../mos_6530/tb/tb_kim_boot.sv) now defaults to the cycle core
(both Verilator and Xezim boot the original monitor, scans=2, 12 segments), so
the functional core's last consumer is
[`system/apple_iie`](../../system/apple_iie/src/apple_iie.sv).

Any change to the decoder, addressing modes or ALU must be mirrored or
independently re-verified in both; a defect can exist in one and not the other.

A cross-core differential now guards that gap: `mos_6502/compare/` runs the same
program on both cores and compares PC/A/X/Y/SP/P and memory contents at every
opcode fetch. Klaus Dormann's functional test agrees for **30,646,183
instructions** (both cores trap at `$3469`). A negative control corrupts one
read in one core and requires the comparison to fail, so the check is not
vacuous. Both run as part of both cores' `run_all.sh`.

`apple_iie` keeps the functional core: its bus contract is one transfer per
clock, and moving it to the cycle core would change the IIe's timing model and
require re-verifying that whole system. With the differential in place the
functional core is no longer unguarded, so the migration is not worth that
risk. Revisit if the IIe needs cycle-level fidelity. Re-basing `mos_6502` as a wrapper over the cycle
core, or replacing its consumers with the cycle core, remains open work
(issue #60, review item C3).
