# Implementation plan

1. Pin original XT BIOS/BASIC, fixed-disk ROM, CGA ROM and PC DOS 2.00.
2. Add full ESC observation and connect the 8087 through byte-bus arbitration.
3. Implement the XT fixed-disk adapter's DCB, DMA3/IRQ5 and decoded-media
   interface. Validate against the unchanged IBM adapter ROM.
4. Adapt the existing CGA/keyboard/web platform to 256 KiB XT RAM, double-sided
   diskettes, persistent 10 MB fixed disk and FPU observations.
5. Boot original POST and DOS; validate disk writes, cold-start persistence
   and CPU-issued floating-point commands. Add protocol/formal/UI checks.
6. Document exact sources, results and boundaries; update the system index,
   commit and open a review PR including its 8087 dependency.
