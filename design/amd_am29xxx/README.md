# AMD Am29xxx series (29K RISC, Am29300/Am29C300, Am295xx)

Canonical issue: [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
One family folder and one series card; one native member sub-issue and one
member subfolder per physical chip. The card tracks three documented device
groups as distinct contracts: the 29K RISC processors, the Am29300/Am29C300
microprogrammable family, and the Am295xx signal-processing support devices.
Member evidence dates each device from its own sources; the 1985 Am29300
Family Handbook anchors the earliest documented subgroup.

| Chip | Member issue | Implementation / sourced history |
| --- | --- | --- |
| am29000 | [#158](https://github.com/hevangel/ai_hw_engineer/issues/158) | planned: members/am29000 |
| am29005 | [#228](https://github.com/hevangel/ai_hw_engineer/issues/228) | planned: members/am29005 |
| am29027 | [#159](https://github.com/hevangel/ai_hw_engineer/issues/159) | planned: members/am29027 |
| am29030 | [#160](https://github.com/hevangel/ai_hw_engineer/issues/160) | planned: members/am29030 |
| am29035 | [#161](https://github.com/hevangel/ai_hw_engineer/issues/161) | planned: members/am29035 |
| am29040 | [#162](https://github.com/hevangel/ai_hw_engineer/issues/162) | planned: members/am29040 |
| am29050 | [#163](https://github.com/hevangel/ai_hw_engineer/issues/163) | planned: members/am29050 |
| am29200 | [#164](https://github.com/hevangel/ai_hw_engineer/issues/164) | planned: members/am29200 |
| am29202 | [#229](https://github.com/hevangel/ai_hw_engineer/issues/229) | planned: members/am29202 |
| am29205 | [#165](https://github.com/hevangel/ai_hw_engineer/issues/165) | planned: members/am29205 |
| am29240 | [#166](https://github.com/hevangel/ai_hw_engineer/issues/166) | planned: members/am29240 |
| am29243 | [#167](https://github.com/hevangel/ai_hw_engineer/issues/167) | planned: members/am29243 |
| am29245 | [#168](https://github.com/hevangel/ai_hw_engineer/issues/168) | planned: members/am29245 |
| am29323 | [#230](https://github.com/hevangel/ai_hw_engineer/issues/230) | planned: members/am29323 |
| am29325 | [#169](https://github.com/hevangel/ai_hw_engineer/issues/169) | planned: members/am29325 |
| am29331 | [#170](https://github.com/hevangel/ai_hw_engineer/issues/170) | [am29331](members/am29331/README.md) |
| am29332 | [#171](https://github.com/hevangel/ai_hw_engineer/issues/171) | planned: members/am29332 |
| am29334 | [#172](https://github.com/hevangel/ai_hw_engineer/issues/172) | planned: members/am29334 |
| am29337 | [#173](https://github.com/hevangel/ai_hw_engineer/issues/173) | planned: members/am29337 |
| am29338 | [#174](https://github.com/hevangel/ai_hw_engineer/issues/174) | planned: members/am29338 |
| am29434 | [#175](https://github.com/hevangel/ai_hw_engineer/issues/175) | planned: members/am29434 |
| am29501 | [#182](https://github.com/hevangel/ai_hw_engineer/issues/182) | planned: members/am29501 |
| am29501A | [#231](https://github.com/hevangel/ai_hw_engineer/issues/231) | shares the am29501 contract (A revision) |
| am29509 | [#232](https://github.com/hevangel/ai_hw_engineer/issues/232) | planned: members/am29509 |
| am29510 | [#183](https://github.com/hevangel/ai_hw_engineer/issues/183) | planned: members/am29510 |
| am29516 | [#233](https://github.com/hevangel/ai_hw_engineer/issues/233) | planned: members/am29516 |
| am29517 | [#234](https://github.com/hevangel/ai_hw_engineer/issues/234) | planned: members/am29517 |
| am29520 | [#184](https://github.com/hevangel/ai_hw_engineer/issues/184) | planned: members/am29520 |
| am29521 | [#185](https://github.com/hevangel/ai_hw_engineer/issues/185) | planned: members/am29521 |
| am29524 | [#235](https://github.com/hevangel/ai_hw_engineer/issues/235) | planned: members/am29524 |
| am29525 | [#236](https://github.com/hevangel/ai_hw_engineer/issues/236) | planned: members/am29525 |
| am29526 | [#237](https://github.com/hevangel/ai_hw_engineer/issues/237) | planned: members/am29526 |
| am29527 | [#238](https://github.com/hevangel/ai_hw_engineer/issues/238) | planned: members/am29527 |
| am29528 | [#239](https://github.com/hevangel/ai_hw_engineer/issues/239) | planned: members/am29528 |
| am29529 | [#240](https://github.com/hevangel/ai_hw_engineer/issues/240) | planned: members/am29529 |
| am29540 | [#241](https://github.com/hevangel/ai_hw_engineer/issues/241) | planned: members/am29540 |
| am29C323 | [#176](https://github.com/hevangel/ai_hw_engineer/issues/176) | planned: members/am29c323 |
| am29C325 | [#177](https://github.com/hevangel/ai_hw_engineer/issues/177) | planned: members/am29c325 |
| am29C327 | [#178](https://github.com/hevangel/ai_hw_engineer/issues/178) | planned: members/am29c327 |
| am29C331 | [#179](https://github.com/hevangel/ai_hw_engineer/issues/179) | shares the am29331 RTL (CMOS process) |
| am29C332 | [#180](https://github.com/hevangel/ai_hw_engineer/issues/180) | planned: members/am29c332 |
| am29C334 | [#181](https://github.com/hevangel/ai_hw_engineer/issues/181) | planned: members/am29c334 |

Historical dates, source qualifications and verification limits remain in
member READMEs and the [design index](../README.md). Different RTL models of
one chip share its member issue. A family grouping does not imply pin
compatibility or common motherboard use. Documented base/A revisions of one
part use one SystemVerilog source with an explicit revision selection and
separate verification contracts (Am29331/Am29331A timing-only delta noted in
the member spec).
