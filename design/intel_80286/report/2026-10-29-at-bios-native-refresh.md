# IBM AT BIOS refresh test on the native 286 bus — 2026-10-29

The unchanged, SHA-256-pinned IBM AT REV1 BIOS now runs in a fixture that
combines the native 286 bus, existing 8254, register-only 8237 adapters,
CPU-visible page-register fixture, port `61h` and the partial 5170 refresh
signal path. The BIOS's original code at `F000:038A`–`03A2` waits for bit 4 of
port `61h` to be both high and low, with an error HLT on failure. The input
comes from the modeled U118 refresh-detect output, not a synthetic toggle.

In `codex-286-bios-native-20261029-01`, the no-wait, virtual timer
half-period 8 scenario reached `F000:03A2` after the original timer, DMA
register and page-register tests. It retired 247,306 instructions in
2,909,415 fixture processor cycles, accepted 21 timer reads, 64 reads from
each DMA controller, 3,573 page reads and 16 port `61h` reads. It observed
2,084 refresh events and 2,084 asserted read-drive pulses, checking successive
LS590 row values, including wrap, and HLDA ownership. Unicorn 2.1.4 compared
all 247,306 CPU instruction states and data transactions, replaying captured
I/O values. In the periodic-READY-stall, virtual timer half-period 11 scenario,
the BIOS reached the same checkpoint after 247,355 retirements and 4,119,716
fixture processor cycles; Unicorn matched all recorded CPU states and data
transactions, including 27 timer reads. This run observed 16 port `61h`
reads, 2,072 refresh signals and 2,072 checked read-drive pulses. Both
scenarios include 64 reads from each DMA controller and 3,573 page reads.
The comparison is an independent CPU check, not an independent oracle for the
peripheral models. The retained job exited 0 and verified all 39 recorded
input hashes after both runs. Its `inputs.sha256` has SHA-256
`0dfd78caaf92c66ad530bb4243973dd58ef690136538f4373b1ba6f6ecbb589d`.
The traces' SHA-256 values are
`298a58f5e816232f96c2f75dc64183804a4acc7c7aa23fd0c4ccecb6d0133838`
and `d2f002f969352146edddb26d964938cf3d3d21211123eaf437d51c7c21e50301`.
The prior port-61 `run_sim.sh` suite also exited 0 with 209 PASS lines in
`codex-286-port61-fullsim-20261029-01`. It was dispatched before the native
BIOS fixture was added; the native BIOS regression is the separate run above.

Reproduce both scenarios with `sh design/intel_80286/scripts/run_at_bios_native.sh
PATH_TO_PINNED_ATBIOS_BIN`. The script validates the ROM checksum, fingerprints
its source inputs, builds with Verilator `-Wall`, runs both scenarios and
checks the trace against Unicorn. It is included in `run_software.sh` and
therefore in `run_all.sh`. The fixture uses explicitly virtual counter and DMA
clocks, externally supplied IOCHRDY and HOLD permit. Register adapters model
canonical addresses only; both DMA controllers have DREQ tied low and do not
perform transfers. The LS590 row and memory-read drive are observed but not
connected to a page mapper, shared DRAM bus, physical DRAM model or retention
check. The U90 cross-coupled asynchronous-clear loop remains a board synthesis
and physical timing limitation. Passing the BIOS indication test is not proof
of DRAM refresh, complete POST, real AT timing or complete 286 correctness.
The checkpoint is recorded in [issue comment 6510781415](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510781415).
