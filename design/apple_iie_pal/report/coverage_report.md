# Apple IIe PAL — Coverage Report

Tool: xezim 0.10.5 `--code-coverage --code-coverage-scope tb_top.dut`,
driven by the full directed + random testbench (`scripts/run_coverage.sh`,
raw JSON at `work/coverage/rtl.json`).

## Result

| Metric | Covered |
| --- | --- |
| Statement | 38/38 (100.00%) |
| Branch    | 10/10 (100.00%) |
| Toggle    | 58/58 (100.00%) |

No exclusions: the reconstruction has no structurally-constant outputs
(every registered output reaches both directions, including VID7M which
tracks the 7M stimulus, and every bit of the tick counter).
