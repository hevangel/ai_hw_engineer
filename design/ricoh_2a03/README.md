# Ricoh RP2A03 / RP2A07

The RP2A03 is the CPU of the Nintendo Family Computer and NES: a second-source
NMOS 6502 core with its decimal-mode adder disabled, plus an on-die audio
processing unit (two pulse channels, triangle, noise and delta-modulation
sample playback), a frame sequencer that can raise IRQs, sprite-memory DMA
and the controller-port strobe/enable outputs. The RP2A07 is the PAL part:
the same logic with a ÷16 clock and PAL timing tables.

**First introduced: 1983.** The chip shipped in the Famicom, released in
Japan on 15 July 1983 ([Family Computer history](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System#History));
the [NESdev CPU page](https://www.nesdev.org/wiki/CPU) documents the
2A03/2A07 variants and the disabled decimal mode, confirmed on the die by
[Visual 2A03](https://www.nesdev.org/wiki/Visual_2A03).

This original SystemVerilog model wraps the repository's
[native NMOS 6502 engine](../mos_6502/README.md) with `DECIMAL_ENABLE=0`
and adds the APU, DMA and I/O logic around it. `REGION` selects 2A03 (NTSC)
or 2A07 (PAL) timing. The reset button (`rst_n`) and power-on (`por_n`) are
separate inputs because the APU keeps most channel state across a reset.

Read the [specification and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md),
[formal properties](formal/ricoh_2a03_props.sv) and
[verification report](report/final_report.md). `scripts/run_all.sh` runs
lint, the independent SingleStepTests CPU vectors, the directed testbench
for both regions, formal and synthesis. Real-software validation (nestest,
blargg CPU/APU/DMA test ROMs) runs in the [NES system](../../system/nes/).
