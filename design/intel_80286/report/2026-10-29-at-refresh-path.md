# IBM AT refresh request-to-detect signal path — 2026-10-29

The [IBM 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 21 (PDF page 11), contains U69/U121's feedback gate, the mutually
clearing U90 selection flip-flops, U98/U116/U81's refresh signal and U70's DMA
HLDA. The [fixture contract](../spec/ibm_at_dma_fixture.md) records the
traced equations and open U120/U92 hold-permit input.

The new standalone [arbiter](../tb/intel_80286_at_refresh_arbiter.sv) passes
Verilator 5.052 `-Wall --assert` checks in retained container
`codex-286-at-refresh-arbiter-20261029-02`. They cover an inhibited request,
no refresh before CPU grant, a refresh grant, a DMA request arriving during
refresh, handoff to DMA, the reverse handoff, and release. Logs are in
`work/at_refresh_arbiter_20261029_02/`.

The [combined path](../tb/intel_80286_at_refresh_path.sv) connects the
previously tested U68/U95 request/clear chain and U118 detector to the
arbiter. Its Verilator test passes in retained container
`codex-286-at-refresh-path-20261029-02`, with logs under
`work/at_refresh_path_20261029_02/`. It drives timer edges, CPU HLDA,
hold permission and IOCHRDY, then checks two request/refresh/detect cycles,
including a wait where the refresh signal remains asserted. It compares the
detector relative to its observed initial value; this does not determine its
physical power-on state. Reproduce from the repository root in the image:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_refresh_path_20261029_02 \
  sh design/intel_80286/scripts/run_at_refresh_path.sh
```

Both the arbiter and combined-path tests are now included in `run_sim.sh`.
The earlier full simulation for the WAIT fix completed before these entries
were added; its result does not include these two tests.

Yosys `proc; opt; check; stat` on the arbiter exits zero but reports **one
structural logic loop**, the U90 cross-coupled asynchronous clear path. This
reflects the modeled schematic feedback; it does not pass a `check -assert`
synthesis gate. Verilator's targeted `SYNCASYNCNET` suppression identifies
the same intentional asynchronous signals. Neither result establishes the
analog settling, simultaneous-request arbitration or physical clock timing.

The combined test does not instantiate an 8254, CPU or DRAM: HLDA is driven
by the test, the `-INTA`/`-WE` hold permit is supplied externally, and no
memory refresh address or port-B read is generated. Connect those pieces,
test true native HOLD/HLDA and memory behavior, and then run the original
BIOS refresh test. Its current checkpoint remains `F000:038A`.
The checkpoint is recorded in [issue comment 6510351122](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510351122).
