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

Decision: both stay. The functional core is instantiated by
[`system/apple_iie`](../../system/apple_iie/src/apple_iie.sv) and the KIM-1
boot bench in [`design/mos_6530`](../mos_6530/tb/tb_kim_boot.sv), so retiring it
is a migration of those consumers, not a deletion. The cycle core is required
for pin-level board models and is the only one the Apple II board proves.

Any change to the decoder, addressing modes or ALU must be mirrored or
independently re-verified in both; a defect can exist in one and not the other.

A cross-core differential now guards that gap: `mos_6502/compare/` runs the same
program on both cores and compares PC/A/X/Y/SP/P and memory contents at every
opcode fetch. Klaus Dormann's functional test agrees for **30,646,183
instructions** (both cores trap at `$3469`). A negative control corrupts one
read in one core and requires the comparison to fail, so the check is not
vacuous. Both run as part of `mos_6502/scripts/run_all.sh`. Re-basing `mos_6502` as a wrapper over the cycle
core, or replacing its consumers with the cycle core, remains open work
(issue #60, review item C3).
