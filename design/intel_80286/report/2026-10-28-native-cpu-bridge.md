# Native CPU-pin bridge checkpoint — 2026-10-28

> **Follow-up:** the core LOCK request is now connected to the native bus
> controller. See the [native LOCK integration report](2026-10-28-native-lock-integration.md)
> for the later implementation, directed checks and remaining lock coverage.

**Checkpoint:** 06:21 UTC  
**Branch/worktree:** `design/intel-80286`, `B:\ai_hw_engineer\worktree\intel-80286`  
**Status:** integrated processor-clock bridge implemented and directed simulation/synthesis pass; full 80286 acceptance remains open.

## Scope

`intel_80286_native_cpu` instantiates `intel_80286` with `NATIVE_BEATS=1` and
connects it to `intel_80286_native_bus`. The wrapper wires the physical
`READY#` input to core completion, moves both 16-bit data lanes, connects
INTR/NMI and the two-cycle INTA/vector exchange, and exposes address, data,
byte-lane, CPU status, LOCK#, HOLD/HLDA, cycle-active, halt/shutdown and fault
signals. The input clock is already one processor clock.

The core's opt-in beat interface reports one or two bytes completed per READY
handshake. Even-addressed words use both data lanes; odd-addressed words split
into lane-correct byte cycles. Descriptor/fetch bytes remain supported, and
the existing default byte-compatible core mode is preserved.

This is a functional bridge at the processor-clock boundary, not complete
native hardware timing. The external clock divide-by-two and reset assertion
and release timing are not modeled. The core does not yet produce a LOCK
request, so the wrapper ties the controller's LOCK input low; only the
controller's hardware INTA lock is exercised. LOCK-prefix and automatic LOCK,
82288 ALE/command strobes, the 80287 interface and physical qualification
remain open.

## Verification

Tools: Verilator 5.052 and Yosys 0.69 from `ai-hw-engineer:latest`.

The connected CPU-pin test passed with even/odd word reads and writes, READY
waits, stable bus pins, HOLD/HLDA release, two-cycle locked INTA, IVT reads,
exact interrupt-frame state and IRET to the exact HLT successor. The retained
log is `work/native-cpu-final-20261028/native_cpu_sim/run.log`.

The current-source `run_sim.sh` completed with exit code 0. Its captured
`work/native-integrated-final-20261028/run_sim.log` contains 141 PASS lines,
including the default CPU suite, component regressions, native-core and
bus-owner tests, the connected CPU-pin test and the protected-mode replay.
The replay manifest
`work/native-integrated-final-20261028/protected_mode_sim_20261028T061955Z/build_manifest.json`
records `result: PASS` for all 79 cases across unstalled and READY-stalled
modes, including protected string/INS fault repair and reset cuts.

The updated `run_synth.sh` completed with exit code 0 for the default core,
native-beat core, component targets, native bus controller and integrated
native CPU wrapper. All 11 Yosys logs contain `Found and reported 0 problems.`
The integrated wrapper netlist has 50,664 generic cells and two submodules.
Its retained Yosys log and JSON hashes are:

| Artifact | SHA-256 |
|---|---|
| `work/native-integrated-synth-20261028/synth/intel_80286_native_cpu.log` | `42A1F9A1C70615F2115B6613AD33B0265857AEEB78D82869790553A65A0A1AD4` |
| `work/native-integrated-synth-20261028/synth/intel_80286_native_cpu.json` | `FD7EADE43C7BBAC4702E07A4AF35BD4BF31AE2A9027432501FBB0B0587BB42C2` |
| `work/native-integrated-final-20261028/run_sim.log` | `366F2B62E25A0A6032BA7642B6767D58DAE5893BB47181987FD01969F63921E4` |
| protected replay `build_manifest.json` | `15B65506AEE6E85DC35891DC6D9BD0C42C9D31B82DB09190231836203D879754` |
| protected replay `replay.log` | `1D68741FFD6A53DBA2B3BC30CB5FA0679EF542B42BD98FE6529B80EC12E02FB7` |

The current manifest binds the protected replay to the modified core and
testbench sources. Key SHA-256 identities are:

| Source | SHA-256 |
|---|---|
| `src/intel_80286.sv` | `18134AF3AF80A9D4600ADBA949146C7019F4AE4D9C3265CC3F9908125748597D` |
| `src/intel_80286_bus_owner.sv` | `1AE776AFA4F33AE8904C9D33FEC3DEDFB31559B239D0592DECDBDA3A3656F3D4` |
| `src/intel_80286_native_bus.sv` | `4C77334502BA7AFEA605E31E6EA8A7BB7A4BDDA6F4FC041062FD48179AA93154` |
| `src/intel_80286_native_cpu.sv` | `B9000BD243C6F5F724396BBF5ADE659B96FDC997CDFBD4BDF0B30702B8025575` |
| `tb/native_core.cpp` | `49DD81FB586B1A028E34C0B6D7E2C7B5E1FEF640F5FED98CF6B6EE0C8E719484` |
| `tb/native_cpu.cpp` | `6DA7E43237DF1D1E4C9EAB69858F2DFC448D35E24C11FCBCD0CB8C53DED2BB36` |

## Reproduction

Run from the repository-mounted `ai-hw-engineer:latest` container, with the
worktree mounted at `/work/worktree/intel-80286`:

```sh
INTEL_80286_WORK_DIR=/work/worktree/intel-80286/design/intel_80286/work/native-cpu-final-20261028 \
  sh design/intel_80286/scripts/run_native_cpu.sh

INTEL_80286_WORK_DIR=/work/worktree/intel-80286/design/intel_80286/work/native-integrated-final-20261028 \
  sh design/intel_80286/scripts/run_sim.sh

INTEL_80286_WORK_DIR=/work/worktree/intel-80286/design/intel_80286/work/native-integrated-synth-20261028 \
  sh design/intel_80286/scripts/run_synth.sh
```

## Remaining acceptance work

- Core LOCK intent has since been connected and tested across memory and
  string I/O forms. See the
  [native LOCK integration report](2026-10-28-native-lock-integration.md).
- Model the selected external clock and RESET timing, then add the separate
  82288 command/ALE layer and source the 80287 protocol.
- Run current-source connected-core formal tasks; the older cover run ended
  with SBY `ERROR`/rc=16 because Yices returned no status and is stale after
  native-beat RTL changes. The corrected depth-12 induction remains UNKNOWN.
- The OS/2 SDK `CPGREP.EXE` run is a Playwright-driven PCjs/OS/2 emulator
  baseline only. It has not executed on this RTL and has no captured
  instruction trace.
- Run the exact-source `run_all.sh` release gate, resolve remaining ISA and
  protected-mode assumptions, and close every row in
  `plans/completion_requirements.md`.

Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, and Sprint
1. The [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6462275940)
records the same results. These checks establish the native bridge slice only,
not a complete 80286.
