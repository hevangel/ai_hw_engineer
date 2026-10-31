# IBM AT port 61h refresh-detect path — 2026-10-29

The [IBM 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 17 (PDF page 9), connects the U127 latch outputs to U128 read-buffer
bits 0–3 and `REF DET`, timer OUT2, `IO CH CK` and `PCK` to bits 4–7.
The latch is cleared by `-RESET`. The fixture implements canonical port
`61h` at completed transactions and connects latch bit 0 to the 8254
channel-2 gate. It does not implement address aliases or the individual
82288 strobe edges. `IO CH CK` and `PCK` are fixture inputs.

The [standalone test](../tb/intel_80286_at_port61_tb.sv) passed with Verilator
5.052 `-Wall --assert` in `codex-286-at-port61-20261029-02`. It checks
reset, stalled and accepted access, the four control bits, all 16 input
combinations for bits 4–7 and exclusion of other addresses. Yosys `proc;
opt; check -assert; stat` found zero problems for this component in
`codex-286-at-port61-yosys-20261029-01`.

The [native integration test](../tb/intel_80286_at_refresh_timer_native_tb.sv)
passed in `codex-286-at-port61-native-20261029-01`: a 286 program writes
the 8254 channel-1 control and count, writes port `61h`, performs 32 exact
memory increments and polls port `61h` until both refresh-detect states
occur. It observed 16 refresh events and five accepted port reads, checked
the odd byte lane and read mapping, and checked a sequential row and
memory-read drive for each refresh. The test supplies virtual clock edges,
IOCHRDY and the unmodeled HOLD permit; the memory-read signal is not connected
to DRAM. The authentic BIOS still runs in a separate functional-bus fixture
and has not passed its refresh test using this native path.

The retained schematic captures under `work/at_refresh_source_20261029_01/`
are `port61_sheet17.png` (SHA-256
`0a9bae64b7056151c6d77426cd55c05590a744bcfedac84601f65f53f7c2f000`)
and `port61_detail.png` (SHA-256
`059f7b2bb5b66c95f5af4936c709d57815e5e8967ced23dafc1be4680cf9e0b0`).
Page mapping, DRAM retention, complete board arbitration and physical bus
timing remain unverified. The U90 cross-coupled clear in the board arbiter
still triggers a Yosys structural-loop warning; the component check above
is not a synthesis pass for the combined board.

The separate CPU synthesis run `codex-286-wait-mf-nmi-synth-20261029-01`
completed with exit 0 using Yosys 0.69. All 18 saved CPU RTL source hashes
matched the workspace after completion. This result does not include the AT
board fixture or establish architectural correctness; the connected-core BMC
and PDR jobs remain active without a terminal proof result.
The checkpoint is recorded in [issue comment 6510702775](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510702775).
