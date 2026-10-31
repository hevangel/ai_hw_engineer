# Native 286 HOLD/HLDA and AT refresh signal path — 2026-10-29

The [native integration fixture](../tb/intel_80286_at_refresh_native.sv)
connects the partial IBM AT U68/U95/U69/U90/U98/U118 refresh path to the
80286 native CPU wrapper's HOLD and HLDA pins. The source circuit and its
remaining U120/U92 hold-permit input are described in the
[signal-path report](2026-10-29-at-refresh-path.md) and the
[fixture contract](../spec/ibm_at_dma_fixture.md).

The native test runs an actual CPU program with an even-word memory write,
a locked memory XCHG, another write and HLT. It requests refresh while the
first write is stalled by READY, then during the locked exchange. It checks
that the stalled write pins remain stable and HLDA stays low, LOCK blocks
HLDA, refresh asserts only after the CPU releases address/data/status pins,
and the program reaches HLT with exactly one write at each expected address
and the expected memory bytes. Two granted refresh signals toggle the
detector twice relative to its observed starting state.

Verilator 5.052 passed in retained container
`codex-286-at-refresh-native-20261029-02`, with build and run logs in
`work/at_refresh_native_20261029_02/`. Reproduce from the repository root in
the image:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_refresh_native_20261029_02 \
  sh design/intel_80286/scripts/run_at_refresh_native.sh
```

The native fixture shares reset between the synchronous CPU core and the
asynchronously cleared board flops; this intentional combination requires
`-Wno-SYNCASYNCNET` for the integration build. The U90 cross-coupled clear
network retains the Yosys structural-loop warning documented in the signal
path report. The script is included in `run_sim.sh`; the refreshed full suite
passed in `codex-286-refresh-native-fullsim-20261029-01`, with 206 PASS lines
and no failure markers. That run includes this native HOLD/HLDA test.

This is a bus-ownership test, not a complete refresh cycle: timer and DMA
clock edges, IOCHRDY and hold permission are test-driven. The 8254, U120/U92
inhibit, row/page address, DRAM behavior, port `61h` and authentic BIOS are not
connected. CDC/metastability, simultaneous DMA/refresh arbitration and analog
timing remain unqualified. BIOS execution remains at `F000:038A`.
The checkpoint is recorded in [issue comment 6510413157](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510413157).
