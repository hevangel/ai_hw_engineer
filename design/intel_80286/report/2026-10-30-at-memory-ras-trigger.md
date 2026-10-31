# IBM AT memory timing trigger — 2026-10-30

The [IBM 5170 type-1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 7 (PDF page 4), feeds `-MEMR` and `-MEMW` to U96 F00. Its NAND
output `+RAS` feeds the U61 PE21213 delay line and additional logic; later
gates combine delayed signals and bank controls to produce the separate
active-low DRAM RAS and CAS outputs. The trigger is therefore not itself a
bank-specific RAS pin or evidence of a completed memory cycle.

The [U96 model](../tb/intel_80286_at_memory_ras.sv) passed all four input
combinations and return to idle with Verilator 5.052 `-Wall --assert` in
`codex-286-at-memory-ras-20261030-01`. Yosys `proc; opt; check -assert; stat`
reported zero problems in `codex-286-at-memory-ras-yosys-20261030-01`.
The separate `codex-286-at-refresh-ras-20261030-01` integration test connects
the timer/request/HLDA/LS125 refresh path to U96 and checks that the trigger
remains asserted through an IOCHRDY stall and clears on release. It also tests
the write input independently. **ASSUMPTION:** the undriven read line is high
and no other master drives it in this test; the shared read/write bus, delay
line, bank select, memory-address multiplexer and DRAM are not yet modeled.
The separate unchanged-BIOS native fixture in
`codex-286-at-bios-ras-20261030-01` passed both virtual-clock/READY scenarios,
checking the trigger against every observed refresh read drive: 2,084 and
2,072 pulses. Unicorn matched 247,306 and 247,355 CPU instruction states and
data transactions with captured I/O; all 41 recorded inputs were verified
afterward. This RAS monitor assumes other masters release the bus during
refresh and does not model normal CPU memory cycles. The standalone and
directed tests are now included in `run_sim.sh`, and the BIOS test in
`run_software.sh`; these additions were tested separately rather than by a
fresh combined run. The retained source capture `work/at_refresh_source_20261029_01/ras_sheet7.png`
has SHA-256 `c7dda3e33d429689897328f35b4e5d7ab3565f468f8e4edd19864ebf36d244b4`.
The separate RAS BIOS fixture and its runner were subsequently consolidated
into `intel_80286_at_bios_native.sv` and `run_at_bios_native.sh` to avoid
maintaining two copies. The consolidated run
`codex-286-bios-consolidated-20261030-01` exited 0: both BIOS/Unicorn
scenarios passed with the same 2,084 and 2,072 refresh counts, and all 41
recorded inputs verified. The earlier retained run remains evidence for its
own source snapshot; `run_software.sh` now invokes the consolidated runner once.
The consolidation is recorded in [issue comment 6516729328](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516729328).
The checkpoint is [issue comment 6516545769](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516545769).
The directed integration and software checkpoint is [issue comment 6516587893](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516587893).
