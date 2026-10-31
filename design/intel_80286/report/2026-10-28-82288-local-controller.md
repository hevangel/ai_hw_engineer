# 82288 local-bus controller implementation — 2026-10-28

Status: the source-backed non-MULTIBUS local (`MB=0`) cycle model is
implemented and connected to `intel_80286_native_cpu`. Directed component and
connected-CPU simulations pass. This is digital protocol evidence, not
electrical timing or physical qualification.

## Model boundary

`intel_80286_82288` is a separate system-interface component. It accepts the
CPU status-valid signal and `{M/IO,S1,S0}` tuple, `CENL`, `CEN`, `CMDLY`, and
active-low READY. It emits ALE, DEN, DT/R, active-low MRDC/MWTC/IORC/IOWC/INTA
and MCE. `intel_80286_native_cpu` now exposes these outputs and takes separate
processor-rate `clk_i` and external 2x `clk_2x_i` inputs. The wrapper does not
derive or phase-lock those clocks; a board/system model must supply their
relationship.

The model implements the source-backed local-bus behavior:

- CENL is active high. Its cycle-start sample selects or suppresses command
  and DEN activation at the end of Ts; an unselected cycle holds DT/R high.
- CEN is an active-high asynchronous command/DEN gate.
- CMDLY is active high and delays command activation at sampled falling edges.
- READY# is sampled at the end of each two-period Tc. High repeats Tc and
  holds strobes; low ends it. A following Ts can begin directly without Ti.
- ALE is active in phase two of Ts, independent of CEN/CENL/CMDLY, and is
  suppressed for halt. Writes may prepare DEN in phase two of Ts before the
  end-of-Ts CENL decision.
- MCE accompanies ALE during INTA and remains active one external CLK period
  after ALE falls.
- The command decode covers memory and I/O reads/writes and INTA; reserved,
  idle and halt tuples issue no command.

The timing profile follows the scanned original Intel HMOS M82288 datasheet
and the compatible Intel M82C288 reference. The source reconciliation is in
[the CENL report](2026-10-28-82288-cenl-source-conflict.md); the full CPU-pin
boundary is in [the native-bus contract](../spec/native_bus_interface.md).

## Verification

The component test in `tb/82288.cpp` checks status strobes, ALE, active-low
polarity, asynchronous CEN gating, CENL selected/unselected reads and writes,
CMDLY delay and early READY completion, repeated READY waits, write-DEN
preparation, direct back-to-back cycles, halt suppression, and the MCE/ALE
interval. It passes with:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/controller_82288_20261028 \
  sh design/intel_80286/scripts/run_82288.sh
```

The connected CPU regression in `tb/native_cpu.cpp` now clocks the controller
at 2x the CPU rate and requires observed ALE, DEN, every exercised memory/I/O
command, INTA and MCE. It also retains the native beat, LOCK, HOLD, interrupt
frame and IRET checks. It passes with:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/controller_82288_20261028 \
  sh design/intel_80286/scripts/run_native_cpu.sh
```

Strict Verilator 5.052 `-Wall` lint passes for the integrated native CPU top.
The complete `run_sim.sh` run passes with 142 PASS lines, including the new
controller and connected-CPU checks and all 79 protected-mode replay cases.
Its replay manifest is
`design/intel_80286/work/controller_sim_20261028/protected_mode_sim_20261028T110934Z/build_manifest.json`.
The complete Yosys 0.69 `run_synth.sh` rerun exited 0 across all 12 targets.
Every target log ends normally and reports zero problems for `check -assert`;
there are no `ERROR:` lines, and all 12 JSON netlists were emitted. The
integrated `intel_80286_native_cpu` top contains 50,824 generic cells including
three submodules; standalone `intel_80286_82288` contains 71 generic cells.
Logs and netlists are retained under
`design/intel_80286/work/controller_82288_20261028/synth/`; the aggregate log
is `work/controller_82288_20261028/run_synth_all.log`.

## Limits and remaining work

The controller implements only the single-local-bus `MB=0` profile; MULTIBUS
delay behavior is not implemented. The wrapper expects externally supplied
processor-rate and system clocks and does not model the 80286 divide-by-two,
clock phase, 82C284 analog `RES` input, power-up interval or clock
synchronizer. The connected CPU test checks a 16-processor-clock RESET pulse
and the `FFFFF0h` first-fetch address; this does not establish electrical
timing. See the [reset source audit](2026-10-28-reset-source-audit.md). The
80287 PEREQ/PEACK/BUSY/ERROR interface, complete descriptor/coprocessor LOCK
rules, released-pin four-state modeling, analog delay/setup/hold, selected
speed-grade limits, and physical qualification remain open. The native
wrapper is outside the current whole-core formal target. This component does
not close the full 286 acceptance ledger or release gate.

## Source snapshot and logs

The Verilator version is `5.052 2026-09-05 rev v5.052`; Yosys is `0.69`
(`9f75ca1f9`). SHA-256 values are recorded for the exact RTL, tests, scripts,
interface contract and simulation logs:

| Artifact | SHA-256 |
|---|---|
| `src/intel_80286_82288.sv` | `53ee70f95f2b506aa9508ff9b5b3efda4d67f36b62a9957efc166f5682540c2d` |
| `src/intel_80286_native_cpu.sv` | `ca526816df085f0c191616a119b20c2546559bc14a1d6291314915c1eef3542f` |
| `tb/82288.cpp` | `b30e658cbc5ef7856ffb7073b5bfbcdb30dfbff33a3576fa28ed37efc1a68d60` |
| `tb/native_cpu.cpp` | `17387f2cfe2dc103c52277abe2ed6cde11334abc4aecff24d37641fc4b2f0c4a` |
| `scripts/run_82288.sh` | `51e11d9f729193ce6bbcc1c5cf6b8b6008ed44f525d57b55ae7c35a598eeeac8` |
| `scripts/run_native_cpu.sh` | `549fbbefdc5a65d9179e9ec294bf0d4e9b45d4748b4d7bda0ae543703bffbd6b` |
| `scripts/run_sim.sh` | `17b6cd8efdb130bcbd335726af8a0a0b2e6f9ba0c82d30558f06ba267a817e18` |
| `scripts/run_synth.sh` | `8f7f58013cdc93d476f2562116652cff1c137d02528da5488d98e621a311d017` |
| `spec/native_bus_interface.md` | `74506a1b45895fccb3b40b68e0d50500b36cc63a8a5fc075002604cdce05ed86` |
| `work/controller_82288_20261028/82288_sim/run.log` | `a66d878fa3830b133d6bbf91530049eb763c5bfe302d2d79cfae887d8d90f0d7` |
| `work/controller_82288_20261028/native_cpu_sim/run.log` | `ef015990561176264786d2487410b6509ff79e2b86ecfae44f741ac79a799cb9` |
| `work/controller_sim_20261028_run_sim.log` | `cf88e30fbb8554b1151bc7fc33ea92dc89deef6a51dd1b9944ba054c0f16b166` |
| `work/controller_82288_20261028/run_synth_all.log` | `29fb7ec1ac8c584da13fa280c420a495fc0849a887a78e8c5d4fd5b3a2fe8a9a` |

These synthesis results establish generic netlist consistency only; they do
not establish timing closure or physical qualification. Issue #80 is the
canonical tracker:
https://github.com/hevangel/ai_hw_engineer/issues/80
