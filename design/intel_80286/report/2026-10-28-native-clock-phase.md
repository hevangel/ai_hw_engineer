# Native CPU clock-phase regression — 2026-10-28

## Change

The connected native CPU test now drives the processor-rate `clk_i` and the
external 2x `clk_2x_i` as one repeatable clock pair. One full processor-clock
period spans two external CLK periods: `clk_i` rises with the first external
CLK rising edge in a pair and falls with the next. This matches Intel's
divide-by-two frequency relationship and the 82288 model's external-clock
domain. The test clock phase is an explicit digital convention; no RTL changed.

This replaces the earlier driver, which advanced the clocks in separate
procedural steps and could not establish their phase relationship. The
connected test still checks 16 processor clocks held in conditioned RESET,
the first fetch at physical `FFFFF0h`, HOLD/HLDA, even and odd word lanes,
READY waits, locked MOV/ROL/XCHG and REP MOVS/INS/OUTS, two-cycle INTA, the
interrupt frame, IRET, and the exercised 82288 outputs.

## Verification

Tools: Verilator 5.052 and g++ 15.2.0 from `ai-hw-engineer:latest`.

Focused connected-pin regression passed:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/native_clock_ratio_20261028_01 \
  sh design/intel_80286/scripts/run_native_cpu.sh
```

The run log is
`work/native_clock_ratio_20261028_01/native_cpu_sim/run.log` (SHA-256
`ef015990561176264786d2487410b6509ff79e2b86ecfae44f741ac79a799cb9`).

The full `run_sim.sh` suite then exited 0 with 162 PASS lines, including the
updated connected-pin test and the protected-mode replay. The replay manifest
reports `PASS` for 79 cases in both unstalled and READY-stalled modes:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/native_clock_ratio_full_20261028 \
  sh design/intel_80286/scripts/run_sim.sh
```

Evidence:

- Full simulation log:
  `work/native_clock_ratio_full_20261028/run_sim.log`, SHA-256
  `5c8a516b35882b5965f0b26e25a5e1dfaf2541f46db4c32b58244f2ab95fdd8c`.
- Connected CPU test log:
  `work/native_clock_ratio_full_20261028/native_cpu_sim/run.log`, SHA-256
  `ef015990561176264786d2487410b6509ff79e2b86ecfae44f741ac79a799cb9`.
- Protected replay manifest:
  `work/native_clock_ratio_full_20261028/protected_mode_sim_20261028T185901Z/build_manifest.json`,
  SHA-256
  `7c59b528ebf62631533f81b17ea770569e617d3d722993098fb73767fda66ffc`.
- Replay binary SHA-256:
  `4e34e84af15ce05442557f4858cb093976ef4a5866f84eda531660f37acb5b17`.

## Source identity

The focused run used these current inputs:

| File | SHA-256 |
|---|---|
| `tb/native_cpu.cpp` | `68323bc75b15288fa7a588f3b33baceb2fbc0a2349ff6c150409ab479f03fe8f` |
| `scripts/run_native_cpu.sh` | `549fbbefdc5a65d9179e9ec294bf0d4e9b45d4748b4d7bda0ae543703bffbd6b` |
| `src/intel_80286.sv` | `fc8576d5bc29eea755315abec7cf77603d309555e5e4cce1442a6dd37ba86fc7` |
| `src/intel_80286_native_cpu.sv` | `2cf4d33af1043ee60e183292769b907007bc90dedd6c3a6524baa5e075df5171` |
| `src/intel_80286_native_bus.sv` | `4c77334502ba7afea605e31e6ea8a7bb7a4bdda6f4fc041062fd48179aa93154` |
| `src/intel_80286_82288.sv` | `53ee70f95f2b506aa9508ff9b5b3efda4d67f36b62a9957efc166f5682540c2d` |

## Limits and next work

The result verifies the connected digital model under a source-defined 2:1
frequency schedule and a declared test phase. It does not implement the board
clock source or qualify clock-to-clock skew, speed-grade limits, pin delay,
82C284 analog `RES` qualification, RESET edge timing, or first-fetch latency.
The single-CPU RESET edge descriptions in Intel 210760-002 printed pages
3-41–3-43 remain inconsistent; see the [reset source audit](2026-10-28-reset-source-audit.md).

The older whole-core PDR remains active against its earlier 21-file snapshot.
Its 18:54 UTC log reached frame 89 with 329/411 outputs proved and 50 timeout
retries. It does not verify the current source, and no formal task was started
by this checkpoint. Current-source connected-core proof and the complete
release gate remain open.

GitHub issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and Start date `2026-10-23`. The checkpoint
was read back at
[comment 6478016839](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6478016839).
