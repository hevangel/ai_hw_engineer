# IBM AT LS590 refresh row and memory-read drive — 2026-10-29

[IBM's 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 21 (PDF page 11), connects U32's LS590 counter and register clocks to
`+REFRESH`, counter enable low, counter clear to `-RESET`, and output-enable
to U95 Q1-bar. Its QA–QH outputs are SA0–SA7. U79's LS125 separately drives
`-MEMR` with Q1-bar when Q2-bar enables the buffer. The
[TI SN74LS590 data sheet](https://www.ti.com/lit/gpn/SN74LS590) states that
the counter and register use rising clocks and that, with clocks tied, the
counter is one count ahead of its register. It describes a direct clear on
the counter, not on the output register.

The [digital model](../tb/intel_80286_at_refresh_row.sv) exposes the row,
its enable, and the distinct LS125 memory-read value and enable; it does not
resolve a shared bus or assume a reset value for the output register. The
standalone Verilator 5.052 `-Wall --assert` test passed in
`codex-286-at-refresh-row-20261029-01`: 260 refresh edges check the pre-increment
row and 8-bit wrap, all enable combinations, counter-only reset and register
capture while reset is active. Yosys `proc; opt; check -assert; stat` passed
with zero problems in `codex-286-at-refresh-row-yosys-20261029-01`.

The counter is connected to the combined refresh path. The path test passes
in `codex-286-at-refresh-row-path-20261029-01`, including row and memory-read
drive during an IOCHRDY stall. The native CPU HOLD/HLDA regression also passes
in `codex-286-at-refresh-row-native-20261029-01`. The CPU-programmed 8254
test passes in `codex-286-at-refresh-row-timer-20261029-01`: all 14 observed
refresh signals produce one asserted memory-read drive with successive row
values `00h`–`0Dh`, while all 32 expected CPU memory increments complete.
The test drives virtual clocks and IOCHRDY, and the memory-read output is
observed rather than connected to DRAM. The earlier captures
`work/at_refresh_source_20261029_01/ls590_wiring.png` and `ti_ls590.png`
have SHA-256 hashes
`3144f41ec632d324a60ee969f7e192be2504fb879f7a6994a0b012e26c5da8b4` and
`299d6182a53199a1897d5a8b478b6030749afbb2938d50e4d24dc58b36206517`.

The model presents SA0–SA7 and a memory-read drive, but it is not yet wired
to the page map or a shared DRAM bus and does not demonstrate real memory
refresh or retention. Actual physical clock, setup/hold and bus timing,
U90's cross-coupled-clear warning, port `61h` and BIOS integration remain open.
The checkpoint is recorded in [issue comment 6510618069](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510618069).
