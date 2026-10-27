# NES implementation plan

1. Build and verify the two console chips first:
   [2A03/2A07](../../../design/ricoh_2a03/) (around the shared native 6502)
   and [2C02/2C07](../../../design/ricoh_2c02/).
2. Board RTL (`src/`): single master clock with the CPU clock derived on the
   falling edge, PPU dot enable, reset button vs power-on, 2 KiB RAM,
   CIRAM, open-bus latch, `$4016/$4017` buffers, two 4021 pads, and the
   cartridge logic for mappers 0-3. Storage in `nes_memory` (blackboxed for
   synthesis) with a side-effect-free host peek port.
3. Host (`host/`): Verilator line-protocol harness (frames, controller,
   reset, peek, screen, audio mixer, instruction trace, FST capture) and a
   web panel with a television canvas, keyboard pad, sound, cartridge
   picker, board state and the Surfer waveform viewer.
4. Software (`scripts/`): hash-pinned fetch of public test ROMs, iNES to
   `$readmemh` conversion, then the regressions: nestest against
   `nestest.log` line by line including cycle counts; blargg suites through
   their `$6000`, zero-page or on-screen result protocols, with automatic
   reset for the reset tests; PAL APU tests on the 2A07 build.
5. Board testbench, backend API test, strict lint in both regions and a
   synthesis check; `scripts/run_all.sh` runs everything.
6. Fix chip bugs the ROMs expose in the chip directories (with the chip's
   own suites rerun), and list every ROM that does not pass with its reason.
