# 80286 reset timing source audit — updated 2026-10-28 19:56 UTC

## Intersil 82C284 reset slice

Playwright CLI review of the [Intersil 82C284 datasheet record](https://www.datasheetarchive.com/datasheet/52cc80015699bffd?term=%252282C284%22%2520Intel)
and its [June 2004 PDF](https://datasheet.datasheetarchive.com/originals/library/Datasheet-026/DSA00463443.pdf)
adds a device-manufacturer source for the later CMOS 82C284. The PDF is marked
as an original Intersil datasheet and also carries an obsolete-product notice.
Printed page 4 says `RES` is active low, `RESET` is active high, `RES` is
synchronized internally at the falling edge of `CLK`, and the input takes one
or two `CLK` periods to affect `RESET`. It also requires RESET high for at
least 16 `CLK` periods for 80C286 processors and support components. Printed
pages 2 and 4 describe `PCLK` as `CLK` divided by two and explain that its
phase can be resynchronized during the first bus cycle after reset.

This corroborates a falling-edge-sampled digital reset path for Intersil's
80C286-oriented part and narrows the Intel manual's edge ambiguity. It does not
establish the behavior or electrical limits of every Intel-manufactured
82C284, nor does it specify a universal first-fetch latency. The standalone
`src/intel_80286_82c284_reset.sv` module models the documented RES polarity and
one/two-falling-`CLK` delay. The datasheet does not select one fixed delay; the
parameter selects either documented value and applies that pipeline to
assertion and release. The native CPU wrapper connects its default two-CLK
output to the core, bus and 82288 controller and retains the already-conditioned
RESET path. The model does not cover analog power-up, oscillator or `CLK`/`PCLK`
generation, phase resynchronization, or physical timing.

## Verification — 2026-10-28

Verilator 5.052 `-Wall` passes the focused component tests at both documented
delay settings. Each test checks falling-edge sampling, polarity, delay and a
16-external-CLK RESET hold. The native CPU regressions pass with conditioned
RESET and with active-low RES through the integrated synchronizer; they check
reset bus quietness, first fetch at `FFFFF0h`, and the existing bus/interrupt
workload. Their run logs are under
`work/df_np_ss_full_20261028/native_cpu_sim/` and
`work/df_np_ss_full_20261028/native_cpu_82c284_reset_sim/`.

The latest full `scripts/run_sim.sh` run exits 0 with 163 `PASS:` lines and no
`FAIL:` or `ERROR:` markers. The exact-source CPU runner manifest has fingerprint
`491ff183671c4d4f164871944aeb7e2ad0eee8ceecc8e410fb7d0b8022e6d2c6`. The
protected replay manifest reports `result: PASS`, 79 cases, and both
unstalled and READY-stalled modes. Logs and manifests are under
`work/df_np_ss_full_20261028/`.

Yosys 0.69 completed the 13-target synthesis matrix, including the reset
component and connected native CPU wrapper. All 13 targets produced a log and
JSON netlist; all 13 logs contain a zero-problem `check -assert` result, with
no `ERROR:` lines. The wrapper netlist includes
`intel_80286_82c284_reset` at the default two-CLK setting. The complete hash
list is `work/82c284_reset_integrated_full_20261028/synth/SHA256SUMS`
(SHA-256 `59676b024ddcfd277a48be92ce7b8cf57753a6c49aac56714ee3ff916c93b731`).

### Selected source and evidence hashes

| Artifact | SHA-256 |
|---|---|
| `src/intel_80286_82c284_reset.sv` | `e70f72be98f244b6d893643268baa6321620af55995cf7f836951b94178203ef` |
| `src/intel_80286_native_cpu.sv` | `659830ce984039c7531d155d3cf027da3735464df9f199c8b81a3d7bb355dcec` |
| `tb/82c284_reset.cpp` | `1a12e1584663234aab6dafe14edc5bd56e4c993afc803c28a6dced3da61558d4` |
| `tb/native_cpu.cpp` | `0618d203314b8403b1614a17ed98e2d08260888656568e0907b69c4b1e7a2d6d` |
| `scripts/run_82c284_reset.sh` | `f011b22feecd052397b246b40b483e600a55396fbeee34af8bf1e87e2e9a9483` |
| `scripts/run_native_cpu_82c284_reset.sh` | `dc9386a13ac3ca228c18d132e76f42b6668e1af1ea28119a17799fea389c7257` |
| `scripts/run_sim.sh` | `37944cc30a72dd0fdf09b9d4303bb743a8c9f160296b84f9b6d47a4730e157b1` |
| `scripts/run_synth.sh` | `1066d19ef08f4906fca05bea4cf2624ec824db02d0834d60c2155634a67be12c` |
| 1-CLK component log | `95b3f3adf647bdbe051633fd86d26c4834ca30ba1add6cca2c85e91c495c33ae` |
| 2-CLK component log | `531aa9a6b9b8d0d580c66f0d1b69a14b5a09386e2eb64cd4e5d252f6a23aca5f` |
| Connected native CPU run logs | `ef015990561176264786d2487410b6509ff79e2b86ecfae44f741ac79a799cb9` |
| Full simulation log | `8ae4a293db2a95035d7f1e6796031a4e89704fa3b05282c5f8cce60a0e11a0f8` |
| Full simulation build manifest | `99a043a007c1cd9ac99cce9024745a2deda0df337ece9df5bfd18e314c0f748d` |
| Protected replay manifest | `1892361bd4bf8f8b3878b52e05d34362ac2d17581c56d53779acb212dd8c93eb` |
| Native CPU Yosys log / JSON | `7c3ca6175da41887e099ef5c39bf767337b98211e14aa63e3244b2a11d383e31` / `4ff88a1b66d951ca0ee73455981058c8c2db32031b6b559e00e26d3f9f94072f` |
| Reset component Yosys log / JSON | `a97f9f6433e765fd1644bfb8fd4f32e8c97bdd67e508acc627d3d3d7f956c810` / `a168e655ee599951821ab86c0c05ed913cadec71bcfdb311139b7b5cec0545e3` |

The active whole-core PDR still uses a different 21-file source snapshot and is
not current-source evidence. No new formal run was started. Issue #80 remains
Building with Agent Codex, Path `ai_hw_engineer/design/intel_80286`, and its
original 2026-10-23 Start date. The latest verification checkpoint was read
back at [comment 6479220404](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6479220404).

## Finding

I inspected Intel's scanned *80286 Hardware Reference Manual*, order
210760-002, using Playwright CLI. Chapter 3, printed pages 3-41–3-43 (PDF
pages 91–93), describes the board-level 82C284 reset sequence:

- Hold its active-low `RES` input below 1.05 V for 5 ms after VCC reaches
  4.5 V, then keep `RES` low for another 16 processor-clock cycles.
- The edge description conflicts for single-CPU use. Page 3-41 says CPU RESET
  high-to-low must be synchronized to system CLK. Pages 3-42–3-43 describe a
  one/two-CLK delay before driving RESET high, say the rising edge may be
  synchronized when VCC/CLK are valid, and allow the falling edge to be
  asynchronous during power-up.
- RESET initializes the 80286's internal divide-by-two clock state. The manual
  describes synchronizing PCLK at the first bus operation after RESET.
- The multi-processor synchronizer in Figures 3-39 and 3-40 is a separate
  board circuit, not the ordinary single-CPU 82C284 sequence.

Source: [Intel 210760-002, 80286 Hardware Reference Manual](https://www.bitsavers.org/components/intel/80286/210760-002_80286_Hardware_Reference_Manual_1987.pdf).

Intel's inspected pages still do not give a consistent single-CPU edge
description or substantiate a fixed 38-external-`CLK` delay from RESET
deassertion to the first bus cycle. The fixed delay has been removed from the
interface contract. The Intersil source supports the standalone digital model
but does not prove the exact behavior of every Intel 82C284 implementation or
remove the need to source the full board clock/reset circuit.

## Changes and evidence

`spec/native_bus_interface.md` now records the device-source scope and keeps
full board-level integration open. The wrapper still accepts the already-conditioned
active-high CPU RESET pin. The connected native-CPU test applies that input
for 16 full processor clocks, checks CPU bus enables/status and 82288 commands
remain inactive on the modeled edges, then checks the first instruction-fetch
status address is physical `FFFFF0h`. It does not test the 82C284 waveform.

Focused verification passed with Verilator 5.052:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/reset_source_20261028 \
  sh design/intel_80286/scripts/run_native_cpu.sh
```

Result: `PASS: connected native CPU pins, HOLD/HLDA, even/odd words, LOCK
MOV/ROL/XCHG and REP MOVS/INS/OUTS, READY waits, two-cycle INTA, interrupt
frame and IRET`. The run log is retained at
`design/intel_80286/work/reset_source_20261028/native_cpu_sim/run.log`.
The subsequent full `scripts/run_sim.sh` run also exited successfully with
the changed connected test and all 79 protected-mode replay cases; its replay
manifest is
`design/intel_80286/work/reset_source_full_sim_20261028/protected_mode_sim_20261028T114448Z/build_manifest.json`.

## Remaining limits

The wrapper accepts already-conditioned processor-rate and external system
clocks. It does not model the 82C284 analog power-up interval, unresolved
single-CPU RESET edge behavior, divide-by-two phase generation, device delays,
or electrical timing. The first-fetch address assertion is digital interface
evidence, not physical qualification. The native wrapper is outside the active
whole-core PDR target, which remains incomplete.
