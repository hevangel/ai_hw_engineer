# NES verification report

## Contract and evidence

`src/nes.sv` is the console board around the repository's
[Ricoh 2A03/2A07](../../../design/ricoh_2a03/) and
[2C02/2C07](../../../design/ricoh_2c02/) RTL: one master clock, CPU clock
÷12/÷16 generated on the falling edge, PPU dot enable ÷4/÷5, 2 KiB work
RAM, 2 KiB CIRAM, CPU open-bus latch, two standard controllers, and NROM,
MMC1, UxROM and CNROM cartridge boards (`src/nes_cartridge.sv`). The
[specification](../spec/spec.md) records sources and assumptions.

Software comes from `christopherpow/nes-test-roms` at revision
`95d8f621ae55cee0d09b91519a8989ae0e64753b`; `scripts/fetch_roms.py`
downloads an allowlist of 86 files and verifies each by git blob SHA-1
before use. ROM bytes stay in ignored `work/`.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33, Python 3, Node Playwright for
the screenshot. Command: `sh system/nes/scripts/run_all.sh`, which printed `PASS: NES complete system verification`.

| Stage | Measured result |
|---|---|
| Lint | `verilator --lint-only -Wall` passes for NTSC and PAL |
| Board testbench | 7 checks: `nestest` automation run to `$C66E` with official and unofficial result bytes `$02`/`$03` = `$00`, no core fault, CPU 1,000 and PPU 3,000 ticks per 12,000 master clocks, frame period 262 × 341 dots |
| `nestest` trace | 8,991 instructions match Nintendulator's `nestest.log` line by line: PC, A, X, Y, P, S and CPU cycle count |
| Test ROMs | 75 PASS, 2 KNOWN (below). CPU: `instr_test-v5` official set, `instr_timing`, `instr_misc`, `cpu_interrupts_v2`, `cpu_reset` (2), `cpu_exec_space` (2), `cpu_dummy_writes` (2), `branch_timing_tests` (3), `cpu_timing_test6`. PPU: `vbl_nmi_timing` (7), `ppu_vbl_nmi`, `sprite_hit_tests_2005` (11), `sprite_overflow_tests` (5), `oam_read`, `oam_stress`, `ppu_open_bus`, `blargg_ppu_tests_2005` (4). APU: `apu_test`, `apu_reset` (6), `blargg_apu_2005` (11), PAL APU tests (10, on the PAL build) |
| Backend API | `scripts/test_backend.py` PASS: request validation, ROM list and LOAD, screen and audio payloads, reset, FST waveform capture and download |
| Synthesis | Yosys generic synthesis of the board with both chips (memories blackboxed by `synth/nes_memory_stub.v`) and `check -assert` pass: 35,238 cells |

Results are read from each ROM's own protocol: the `$6000` status with the
`DE B0 61` signature and text at `$6004`, the zero-page result byte of the
older suites, or the on-screen `PASSED` text of `cpu_timing_test6`. A ROM
that does not report within its frame budget fails.

## Known differences

- `instr_test-v5/all_instrs`: only the unofficial `LXA #imm` ($AB) test
  fails. Its magic constant differs between real consoles; the CPU uses $EE
  as in the SingleStepTests oracle, blargg's ROM expects $FF. The other
  `instr_test-v5` ROMs pass.
- `blargg_ppu_tests_2005/power_up_palette` compares palette RAM at power-up
  with the author's own console; the model powers up with zeros.
- `cpu_dummy_reads` and the two `sprdma_and_dmc_dma` ROMs report only on
  screen in a form the harness does not parse yet (no `$6000` status within
  600–900 frames), so they are left out of the regression and unverified.
  `instr_misc` does cover APU-register dummy reads.

## Limitations

The web panel runs the Verilator model at about 10 frames per second (NTSC,
`-O3`), so games are playable but slow. Composite video, the analog audio
path, expansion ports, mappers beyond 0–3, and the MMC1 PRG-RAM disable
bit are not modelled. The Surfer viewer embedded in the panel exists only
in the project Docker image; the Docker run of `run_all.sh` is still owed.
