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

Decision: both stay, because the functional core serves systems that need a
one-transfer-per-clock bus and the cycle core is required for pin-level board
models. Any change to the decoder, addressing modes or ALU must be mirrored or
independently re-verified in both; the Apple II board only proves the cycle
core. Re-basing `mos_6502` as a wrapper over the cycle core remains open work
(issue #60, review item C3).
