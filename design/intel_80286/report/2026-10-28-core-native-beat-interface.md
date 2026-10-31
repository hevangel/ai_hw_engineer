# Core native-beat interface checkpoint

**Status:** the functional core now has an opt-in one/two-byte completion
boundary and passes focused CPU/event traffic, full default simulation and
both parameterized top-level synthesis checks. The separate native CPU-pin
controller is still not connected, so this is not a complete pin-level 80286.

## Change

`intel_80286` now has `NATIVE_BEATS`, defaulting to `0` for compatibility.
In native mode its read/write data boundary is 16 bits, `bus_beat_bytes_o`
reports the bytes completed by READY, and `bus_size_o` gives the remaining
logical-operation byte count. An even-addressed data word uses one two-byte
beat. An odd-addressed word splits into two byte beats with the proper D7:D0
or D15:D8 lane. Instruction fetches and descriptor-engine requests remain
byte beats. The CPU/event bus owner holds both data lanes across waits and
routes the full read word back to the selected client.

The event-path simulation executes `INT 30h` from a small real-mode program,
reads the IVT using two even-word beats, pushes the FLAGS/CS/IP frame as three
word beats, executes IRET using three word beats, and reaches the exact HLT
successor. The test checks frame bytes and beat addresses/sizes. The core path
also stores and reloads a word at an even address and a word straddling an odd
address. The independent bus-owner test drives distinct upper/lower lane data
through READY waits and checks stable ownership and reset cancellation.

While running the existing default CPU regression, the changed segmented
descriptor validation also exposed a distinction between invalid descriptor
data and its descriptor class. Invalid access bytes are now masked from the
cache commit while a classification-only sideband carries the type bits needed
for task-gate incoming-SS fault selection. The full segment and protected-mode
regressions pass with that correction.

## Reproduction and results

Commands run in `ai-hw-engineer:latest` from the task worktree:

```sh
sh design/intel_80286/scripts/run_synth.sh
sh design/intel_80286/scripts/run_native_core.sh
sh design/intel_80286/scripts/run_bus_owner.sh
sh design/intel_80286/scripts/run_sim.sh
```

| Check | Result | Retained evidence |
|---|---|---|
| Yosys 0.69 default core synthesis and `check -assert` | Pass | `work/native-beat-synth-20261028/synth/intel_80286.log` and `.json` |
| Yosys 0.69 `NATIVE_BEATS=1` core synthesis and `check -assert` | Pass; 50,433 generic cells including submodules | `work/native-beat-synth-20261028/synth/intel_80286_native_beats.log` and `.json` |
| `NATIVE_BEATS=1` CPU/event directed simulation, Verilator 5.052 `-Wall` | Pass: even/odd words, IVT, exact interrupt frame, IRET | `work/native-beat-core-event-final-20261028/run.log` |
| Bus-owner directed simulation, Verilator 5.052 `-Wall` | Pass: stable ownership through waits, full lane values, reset cancellation | `work/native-beat-owner-highlane-20261028/run.log` |
| Current default `run_sim.sh` | Exit 0; full CPU and protected-mode suites pass, including 79-case protected replay manifest | `work/native-beat-final4-20261028/run_sim.log`, `sim/build_manifest.json`, `protected_mode_sim_20261028T054457Z/build_manifest.json` |

The exact-source Yosys run produced the default and native top-level netlists
and all component netlists from `scripts/run_synth.sh`. The native top-level
JSON is about 30 MB; the full conversion took about 410 seconds and peaked at
about 1.1 GB according to Yosys. The `run_sim.sh` log contains the component
case counts and protected-mode replay cases. This is the focused simulation
entry point, not the aggregate `run_all.sh` release gate.

## Source and evidence identities

SHA-256 values are over the retained files from this worktree:

| Artifact | SHA-256 |
|---|---|
| `src/intel_80286.sv` | `18134af3af80a9d4600adba949146c7019f4ae4d9c3265cc3f9908125748597d` |
| `src/intel_80286_bus_owner.sv` | `1ae776afa4f33ae8904c9d33fec3dedfb31559b239d0592decdbda3a3656f3d4` |
| `src/intel_80286_segment_check.sv` | `b1e61b08972a5d9cd34106be9f0f2a253a58ac165c378474b5837daf1f814dea` |
| `src/intel_80286_segment_load.sv` | `a20c226714d0a97e24688f63672ad408adb453d1f5c8599a006776e7bbfe7816` |
| `tb/native_core.cpp` | `49dd81fb586b1a028e34c0b6d7e2c7b5e1fe640f5fed98cf6b6ee0c8e719484` |
| `tb/bus_owner.cpp` | `4da717b209cf4c947c802f44e1499376573820bc904ff8944e65051636886cd0` |
| Native Yosys log | `bd7b03f7cea07854b467c37d9f293b138d1b5265b4a0c9ebaeff994c883be9ad` |
| Native Yosys JSON | `5a654e26d5a3c76498c57374c2d7fd623adc4a4ead41bf710abe829f7a1a6a91` |
| Native core test log | `562a607167ec6d5385c8d936909ac217ed7ad1a81b0c5b792913ba18d6f6803a` |
| Bus-owner test log | `878e0cd92694f5f60026a90d5f9a81ab61c43a2bf4128ad17b9191ba24ee27af` |
| Full `run_sim.sh` log | `66ca612bf50d7dee410068b15d3a3f22f471e5130d6823e89b0cf1c8020f2d07` |

## Boundaries and remaining work

- `intel_80286_native_bus` is not instantiated in the core. The focused core
  test uses a memory/READY testbench, not the native CPU pins.
- Core READY, data, status timing, reset/clock division, HOLD/HLDA, automatic
  LOCK, pin output-enable behavior, and the separate 82288 command interface
  still need a connected wrapper and exact pin-level regressions.
- Native-mode descriptor transfers remain byte beats. Processor-extension
  PEREQ/PEACK/BUSY/ERROR behavior needs the sourced 80287 protocol.
- No current-source connected-core BMC, induction proof, cover audit or PDR
  result covers this change. The previous formal snapshots remain bounded,
  stale or incomplete as recorded in `plans/286/STATUS.md`.
- The SDK 1.00 CPGREP run is still independent PCjs/OS/2 evidence; the core
  has not executed that software. Full 80286 and release acceptance remain
  incomplete.
