# Ricoh RP2A03 / RP2A07 verification

## Contract and evidence

`ricoh_2a03.sv` wraps the shared native NMOS 6502 engine
(`design/mos_6502_family/mos_6502/src/mos_6502_native.sv`, unchanged) with
`DECIMAL_ENABLE=0` and adds the APU (two pulse channels, triangle, noise,
DMC, frame sequencer, `$4015` status), OAM and DMC DMA with cycle-exact
halt/alignment, the `$4016` strobe and `/OE` controller outputs, and
separate reset-button (`rst_n`) and power-on (`por_n`) behaviour. `REGION`
selects 2A03 (NTSC) or 2A07 (PAL) tables. The
[specification](../spec/spec.md) lists sources and the assumption ledger.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33. SymbiYosys and xezim are not
installed there, so formal ran through a local stand-in that drives the
same `.sby` task through Yosys `read -formal`, `prep`, `async2sync`, and
ABC `bmc3` / `pdr` / cover search, and the second simulator was skipped.
`scripts/run_all.sh` in the project Docker image runs the real tools; that
run is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes for both regions |
| Independent CPU vectors | SingleStepTests `nes6502` (decimal disabled): 2,559,513 cases across all 256 opcodes, 11,956,075 exact bus cycles |
| Directed testbench | 33,979 checks (NTSC) and 37,402 checks (PAL): OAM DMA length 513/514 and byte order, DMC DMA, frame IRQ cycle and `$4015` clear, length counters, pulse duty/period/sweep, triangle, noise LFSR against a reference, controller strobes |
| Formal | BMC and PDR proof at depth 20 PASS; 17/17 covers reached within 28 steps |
| Synthesis | Generic Yosys synthesis and `check` pass: 7,835 cells (NTSC), 7,858 cells (PAL) |
| Real software (NES system) | `nestest` 8,991-instruction trace exact including cycle counts; blargg `instr_test-v5`, `instr_timing`, `instr_misc`, `cpu_interrupts_v2`, `cpu_reset`, `cpu_exec_space`, `cpu_dummy_writes`, `branch_timing_tests`, `cpu_timing_test6`, `apu_test`, `apu_reset`, all 11 `blargg_apu_2005` tests, and the 10 PAL APU tests pass |

Bugs found by the test ROMs and fixed in the RTL: the frame sequencer now
applies events one CPU cycle earlier (the IRQ flag is readable 29,831 to
29,833 cycles after a `$4017` write on an APU cycle), a frame-IRQ set wins
over a same-cycle `$4015` read clear, a length reload written while a
non-zero counter is clocked is ignored, and `/RST` no longer clears channel
registers or the frame mode (only power-on does). Adding `por_n` exposed
uninitialised lengths in formal; the property file now assumes power-on is
asserted whenever reset is during the initial window.

## Known differences

- `instr_test-v5/all_instrs` fails only on unofficial `LXA #imm` ($AB):
  its magic constant varies between real chips. The core uses $EE (the
  SingleStepTests oracle); blargg's ROM expects $FF.
- `cpu_dummy_reads` and `sprdma_and_dmc_dma` (OAM/DMC DMA overlap) report
  only on screen and are not yet parsed by the NES harness, so those
  behaviours are unverified by software.

## Remaining gates

Electrical behaviour, the analog DAC/mixer (approximated in the NES host),
the test-mode pins and CPU-to-APU clock phase alignment at power-on beyond
the documented jitter are not modelled.
