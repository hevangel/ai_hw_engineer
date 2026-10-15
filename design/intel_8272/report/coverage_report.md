# Intel 8272A coverage report

Measurement uses Xezim code coverage scoped to `tb_top.dut`, seed 2026, from `scripts/run_coverage.sh`. This is controller instance coverage, separate from the exhaustively checked word codec and CRC vectors. Functional UVM command coverage measures all 15 opcode bins only. Its 100% result is not complete functional or cross coverage.

Macros expand repeated procedural completion/request fragments at distinct call sites, so statement totals exceed the source line count. No uncovered statements, branches or toggles are excluded from reported percentages. Reduced millisecond timers and short simulations leave upper timer bits inactive; toggle coverage is also reduced by fixed unit/geometry patterns and reserved bits. A low toggle count is not interpreted as proof that those bits are unnecessary.

Remaining directed coverage gaps include invalid sector-size/STP parameters, some Read Track CRC/mark continuation combinations, malformed/too-early backend byte/write-slot overruns, format SC=0 in the standalone suite (covered through UVM instead), and result-ID/status combinations at completion fragments. Formal safety does not replace these missing semantic tests. Ready-event replacement/acknowledgement collisions, maximum default head/seek timer values and broad opcode/flag/density/timing crosses are not exhaustively tested. Raw track coverage remains absent. Original BIOS/PC DOS and DMA integration are measured separately in the IBM PC system regression.

Final measurement on October 14, 2026, including READY-event, final format-ID TC and DACK-only VERIFY regressions:

| Metric | Covered / total | Percent |
|---|---:|---:|
| Statements | 638 / 780 | 81.79% |
| Branch arms | 234 / 279 | 83.87% |
| Toggles | 474 / 876 | 54.11% |
| UVM opcode bins | 15 / 15 | 100.00% |

The controller suite passed 75,432 checks for the coverage seed. Exact uncovered
line/expansion information is retained in `work/coverage/rtl.json`; completion
macros can leave particular combinations uncovered at otherwise exercised lines.
The separate 4 MHz timing suite performs 58 checks in each simulator and is not
merged into these controller coverage totals. No claim of full branch/toggle
closure is made. Full-sector writes at every N, all reserved opcode-flag
encodings, every scan wildcard/timing combination and simultaneous READY-event
acknowledgement collisions need further coverage before stronger claims.
