# IBM PS/2 Model 30 implementation plan

1. Pin original Model 30 ROM sockets and 720 KiB historical boot media;
   document manufacturer references and independent gate-array authorities.
2. Wire the native maximum-mode 8086 chip, planar memory/byte-I/O bridge,
   RQ/GT refresh/DMA arbitration and existing peripheral RTL.
3. Implement the Model 30 keyboard/mouse gate array, MM58167 RTC, planar
   controls, MCGA registers/DAC/loadable fonts and serial/parallel interfaces.
4. Adapt the external memory/media bridge for 640 KiB RAM, interleaved ROM,
   64 KiB VRAM and 80-cylinder/two-head/nine-sector drives.
5. Boot unchanged BIOS and IBM Starter Disk/PC DOS 3.30. Investigate every
   diagnostic; add directed tests and failure notes for escaped defects.
6. Add the Model 30 front panel, 101-key keyboard, MCGA renderer and 8 MHz
   Surfer waveform presets. Keep the 5150 system independently runnable.
7. Run lint, formal/cover, synthesis, board/media/backend/waveform and real
   software regressions. Document measured results and limitations; open PR.

8. Add the user-requested original fixed disk: document DBA contracts before
   RTL, connect DMA 3/IRQ5/presence, implement controller/media/ECC and
   persistence, update the front panel, then install/boot DOS using original
   FDISK/FORMAT/COPY with independent FAT16 verification.
