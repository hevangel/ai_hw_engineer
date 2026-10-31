# CPU-programmed 8254 to native refresh signals — 2026-10-29

The [native timer fixture](../tb/intel_80286_at_refresh_timer_native.sv)
connects the shared 8254 through canonical AT I/O ports to the 286 native bus,
and connects channel-1 OUT1 to the partial U68/U95/U69/U90/U98/U118 refresh
path. It latches native I/O status, uses the proper odd-address byte lane and
strobes timer accesses only when the CPU beat completes. The
[fixture contract](../spec/ibm_at_dma_fixture.md) records the remaining
limitations.

The directed CPU program writes `74h` to port `43h` and count `0008h` to
`41h`, then executes 32 memory increments and halts. The test applies two
READY waits to each of the three timer writes, checks each value and lane,
compares every memory write to the exact expected sequence, and requires each
observed refresh signal to follow a programmed OUT1 rising edge. Refresh must
follow CPU HLDA and the CPU must release its bus pins. The tested virtual
clocks produce 14 refresh signals while the 32 writes complete.

The Verilator 5.052 `-Wall --assert` run passed in retained
container `codex-286-at-refresh-timer-native-20261029-05`; its evidence is
under `work/at_refresh_timer_native_20261029_05/`. Five selected CPU, timer,
fixture and test source hashes matched between dispatch and completion; the
hash list is saved as `source_hashes.txt` in that directory. Reproduce from the repository
root in the repository image:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_refresh_timer_native_20261029_05 \
  sh design/intel_80286/scripts/run_at_refresh_timer_native.sh
```

An earlier less strict run passed, and the subsequent provenance/stall run
showed that a periodic READY pattern did not actually stall the three timer
writes. The current test forces two waits per write. The script is included in
`run_sim.sh`; previous full-suite results do not include this new test.

After connecting the LS590/LS125 model, the same test passed in
`codex-286-at-refresh-row-timer-20261029-01`: it also checks that the 14
refresh-signal events each produce a bus-granted memory-read drive with the
corresponding row in sequence from `00h` to `0Dh`. This is a driven-signal
check; no DRAM consumes these strobes. See the
[refresh-row report](2026-10-29-at-refresh-row.md).

The fixture still drives the 8254 counter clock, `-DMA CLK`, IOCHRDY and the
unmodeled U120/U92 hold permit. The native timer read path is not exercised.
There is no page-register wiring, DRAM refresh behavior,
port `61h`, authentic BIOS integration or physical clock/analog qualification.
Yosys reports the U90 cross-coupled asynchronous-clear path as a structural
loop; the native fixture uses a targeted reset warning suppression described
in the [native report](2026-10-29-at-refresh-native.md). This is not a full
AT refresh, POST or CPU acceptance result.
The checkpoint is recorded in [issue comment 6510544314](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510544314).
