# 2C02 / 2C07 implementation plan

1. Source register semantics, frame timing, the background fetch pipeline,
   sprite evaluation (with the overflow bug), sprite-zero hit and palette
   rules from NESdev (Visual 2C02-derived) before RTL; record model choices
   in the spec's assumption ledger.
2. Clock all state from the master oscillator with `dot_ce` and `cpu_ce`
   enables so the PPU and CPU share one clock domain in the system. Register
   side effects happen at the end of the CPU cycle and read data is latched
   there.
3. Implement the register block (`t`/`v`/`x`/`w`, read buffer, decaying I/O
   latch, vblank/NMI with the read-race suppression), the background
   pipeline, and a separate sprite module (OAM, secondary OAM, dot-sequenced
   evaluation, fetch addressing, eight output units). `REGION` selects the
   2C07 line count and removes the odd-frame skip.
4. Verification:
   - Independent reference renderer in the testbench: a full frame with
     scrolling, attributes, flipped/behind sprites and left clipping is
     compared pixel for pixel, in both regions; plus frame timing,
     vblank/NMI race, read buffer, palette mirroring, `w` toggle, sprite-0
     timing, overflow and odd-frame skip checks.
   - Formal: raster bounds, pixel-valid window, flag clear on the
     pre-render line, NMI equation, with reachable covers.
   - Real software in [system/nes](../../../system/nes/): blargg
     `ppu_vbl_nmi`, `vbl_nmi_timing`, sprite hit/overflow, `oam_read`,
     `oam_stress`, `ppu_open_bus` and the 2005 PPU tests.
5. Strict lint for both regions and a Yosys synthesis check. Publish
   measured results and open gaps in the report.
