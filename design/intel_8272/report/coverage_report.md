# Intel 8272A coverage report

Measurement uses Xezim code coverage scoped to `tb_top.dut`, seed 2026, from `scripts/run_coverage.sh`. This is controller instance coverage, separate from the exhaustively checked word codec and CRC vectors. Functional UVM command coverage measures all 15 opcode bins only. Its 100% result is not complete functional or cross coverage.

Macros expand repeated procedural completion/request fragments at distinct call sites, so statement totals exceed the source line count. No uncovered statements, branches or toggles are excluded from reported percentages. Reduced millisecond timers and short simulations leave upper timer bits inactive; toggle coverage is also reduced by fixed unit/geometry patterns and reserved bits. A low toggle count is not interpreted as proof that those bits are unnecessary.

Remaining directed coverage gaps include invalid sector-size/STP parameters, some Read Track CRC/mark continuation combinations, malformed/too-early backend byte/write-slot overruns, format SC=0 in the standalone suite (covered through UVM instead), and result-ID/status combinations at completion fragments. Formal safety does not replace these missing semantic tests. Ready-event replacement/acknowledgement collisions, maximum default head/seek timer values and broad opcode/flag/density/timing crosses are not exhaustively tested. No raw track or historical operating-system coverage is claimed.

Final measurement on October 2, 2026:

| Metric | Covered / total | Percent |
|---|---:|---:|
| Statements | 632 / 773 | 81.76% |
| Branch arms | 236 / 281 | 83.99% |
| Toggles | 470 / 872 | 53.90% |
| UVM opcode bins | 15 / 15 | 100.00% |

The controller suite passed 74,591 checks for the coverage seed. The 12 source lines with one or more uncovered expanded statements are 314, 316, 321, 344, 357, 359, 381, 393, 430, 435, 437 and 443 in `src/intel_8272.sv`. Several lines expand completion macros, so only some argument/condition combinations at a line may be absent. No claim of full branch or toggle closure is made. Full-sector writes at every N, all reserved opcode-flag encodings, both sides of every scan wildcard/timing combination and simultaneous ready-event acknowledgement collisions need further regression coverage before stronger compatibility claims.
