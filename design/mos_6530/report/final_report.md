# MOS 6530 RRIOT validation report

Validated 2026-10-19 in `ai-hw-engineer:latest`. Both KIM-1 mask variants
are implemented, including their actual ROM bytes and different decode
equations. Sampled digital verification and original monitor execution
pass. Physical pin/timing fidelity and the full four-system objective
remain incomplete.

## Results

| Gate | Result |
|---|---|
| ROM provenance/integrity | PASS, both 1024-byte images and packed RTL constants match recorded SHA-256 values |
| Strict Verilator RTL/TB lint | PASS; only mixed-timescale warning suppressed for benches |
| Formal BMC | PASS, 16 steps |
| Formal unbounded proof | PASS, ABC PDR |
| Formal cover | PASS, all six goals reachable within 16 steps |
| Verilator chip regression | PASS, 214,886,274 checks, 2,048 timer configurations |
| xezim chip regression | PASS, 2,066,118 checks, 40 timer configurations across both masks |
| Original KIM monitor, Verilator | PASS, two ordered scans, 12 segment writes, one mask-RAM write, 5,444 functional CPU bus clocks |
| Original KIM monitor, xezim | PASS, same checkpoints and counts |
| Yosys 6530-002 synthesis/check | PASS, 4,096 generic cells with real monitor ROM, zero reported problems |
| Yosys 6530-003 synthesis/check | PASS, 3,536 generic cells with real cassette ROM, zero reported problems |

Toolchain: Verilator 5.052, Yosys 0.69 (`9f75ca1f9`), SBY v0.69,
xezim 0.11.0 (`6558a1e`). Generic cell counts include ROM implementation
and SRAM, not just control logic, and are not physical area/timing estimates.

## Scope of the evidence

Both original ROM images are read byte-for-byte through the actual mask
instances and resist writes at every byte. The 8 KB unexpanded KIM map is
exhaustively checked for selection, ROM/RAM contents and mutually exclusive
output enables. The two 64-byte RAMs retain distinct contents over reset.
Tests cover all DDR masks on both chips, reserved PB6 ownership, all
register/timer aliases, independent chip flags and shared PB7 GPIO/IRQ.

For each mask, every byte load is tested at /1,/8,/64,/1024, checking each
clock's count and IRQ through N*P+1 expiry and the next two clocks using
elapsed-time equations. xezim uses loads 0,1,2,52,255 at each divisor/mask
and the same non-sweep tests. Status reads do not acknowledge; a simultaneous
count-read/expiry retains the flag; later count reads restore the original
divider and disable IRQ even at the enabled address, as KIM Appendix H
states. GPIO PB7 ownership overrides timer drive as required.

The independent manufacturer monitor starts at exact reset PC 1C22, then
executes 1C24,1C25,1C27 with the listed opcodes. It initializes the actual
6530 registers/RAM and produces two six-digit display passes, each with
digit enables 09,0B,0D,0F,11,13 followed by 15 (off), and twelve BF zero
segment patterns. The bench supplies no keys and zero-filled board SRAM.
The original ROM is neither patched nor padded to tolerate PC errors.
This exercises monitor ROM 002; the cassette ROM 003 is verified bytewise
but its complete tape load/save routines are not executed here.

Formal proofs cover decode nonoverlap for the default mask, ROM readback,
arbitrary-address SRAM write/retention, reset/register isolation, reserved
pin output suppression and timer state/acknowledgment rules. Covers reach
ROM and RAM reads, enabled/masked expiry, GPIO override and post-expiry
enabled-alias acknowledgment. The exhaustive shared-bus simulation also
checks the 003 mask; unbounded proof is run on the configurable base core
with its default 002 decode and default constant ROM.

## Reproduction

```sh
docker run --rm -v "$PWD:/workspace" -w /workspace --entrypoint sh \
  ai-hw-engineer:latest design/mos_6530/scripts/run_all.sh
```

Logs/witnesses/generated netlists remain ignored under `work/`. Original
mask bytes, hashes and regeneration instructions are in
[references](../references/README.md). Simulation scripts require both
successful process completion and the explicit PASS marker.

## Remaining sign-off gates

The [specification](../spec/spec.md) retains unresolved native timing,
reserved DDR readback, pin-mask capture and electrical/reset details.
The firmware harness uses the existing 6502 functional-bus core and an
explicit phase adapter. Its 5,444 clocks are **not** authentic NMOS CPU
instruction-cycle timing. This is a chip regression harness, not a released
system, and does not replace the required Atari/C64/NES/SNES integrations.
The complete reconstruction goal remains open in the
[series ledger](../../../plans/mos_historical_series.md).
