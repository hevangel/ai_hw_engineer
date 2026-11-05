# Intel 8086 / 8088 — distinct external-bus profiles

Two canonical chip issues, each with its own public timeline card. This folder groups their implementations because they share an architecture, but a shared execution unit does not make the chips pin-compatible.

| Chip | Canonical issue | Implementation / sourced history |
| --- | --- | --- |
| Intel 8086 (1978) | [#22](https://github.com/hevangel/ai_engineer/issues/22) | [intel_8086](intel_8086/README.md) |
| Intel 8088 (1979) | [#271](https://github.com/hevangel/ai_engineer/issues/271) | Planned at `intel_8088/`; no tracked implementation found |

The two issues were one family tracker (#22 with sub-issues #270 and #271) until the 2026-11-03 split. The IBM PC 5150 and XT 5160 are gated by the 8088 issue; the IBM PS/2 Model 30 by the 8086 issue.

Historical dates, source qualifications and verification limits remain in member READMEs and the [design index](../README.md). Different RTL models of one chip share its issue. Shared Apple II package models are linked from their member profiles; no RTL is duplicated. Generic/unknown parts remain explicit inventory gaps.
