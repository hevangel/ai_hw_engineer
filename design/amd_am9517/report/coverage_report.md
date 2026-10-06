# Am9517 observed coverage

The complete flow passed on October 3, 2026. The xezim code-coverage run uses
the native seed-1 testbench and reports scope `tb_top.dut`:

| Metric | Covered / total | Percentage |
|---|---:|---:|
| Statement | 153 / 154 | 99.35% |
| Branch | 112 / 117 | 95.73% |
| Toggle | 256 / 256 | 100.00% |

These are tool-reported metrics for that scope, not proof of exhaustive historical
state coverage. The uncovered statement is the illegal-FSM recovery default at
RTL line 324. The formal legal-state assertion excludes that recovery path during
supported operation. Five branch alternatives remain uncovered; their absence
is retained in the results rather than silently excluded from the denominator.

UVM covers all four channels crossed with the three legal transfer types,
checks 144 DMA transfers and 216 register reads, and reports zero errors/fatals.
The native suite checks 350,971 expectations and 66,892 transfers. Separate
original-software and actual cascade suites provide additional integration
evidence without inflating the native code-coverage numbers.

All eleven formal covers are reached within depth 36, including all channels,
verify service, READY wait, cascade, terminal count/reload and memory-copy
source/destination phases. BMC and unbounded PDR also pass.

Run `scripts/run_coverage.sh` to regenerate `work/coverage/rtl.json` and its
summary. See the [validation report](final_report.md) for scope and diagnostics.
