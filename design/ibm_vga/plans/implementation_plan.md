# IBM PS/2 Display Adapter: implementation plan

Issues: [hevangel/ai_hw_engineer#274](https://github.com/hevangel/ai_hw_engineer/issues/274)
(VGA chip set) and [#275](https://github.com/hevangel/ai_hw_engineer/issues/275)
(ISA card). Branch `design/ibm-vga`, based on `design/ibm-ega` (the EGA, not
yet merged) so that its modules can be copied and its slot contract kept.

## Approach

1. Sources: HITR (PS/2 Hardware Interface Technical Reference, Type 1
   video), VGAXGA (May 1992), the adapter ROM (86Box/MAME dumps), checked by
   `scripts/get_rom.py`. Spec and assumption ledger first
   ([spec](../spec/spec.md)).
2. RTL by copying the EGA module that does the same job and extending it to
   the VGA (each file names its EGA origin):

   | VGA module | from | main changes |
   |---|---|---|
   | `vga_io_decode` | `ega_io_decode` | VGA port set, 46E8h/102h, enable/setup gating, 32 KB ROM window |
   | `vga_general_regs` | `ega_ext_regs` | readable Misc/FCR, 46E8h, POS, 25/28 MHz select, sense bit; no switches, light pen |
   | `vga_sequencer` | `ega_sequencer` | chain 4, 3-bit character maps, Screen Off, readback |
   | `vga_crtc` | `ega_crtc` | HT+5, 10-bit vertical, protect, double scan, doubleword/count by 4, cursor off, readback |
   | `vga_graphics_ctrl` | `ega_graphics_ctrl` x2 | one controller for four maps, write mode 3, 2-bit read map, 256-colour serializer, readback |
   | `vga_display_fetch` | `ega_display_fetch` | 3-deep data history, 7-deep flag history, 8 KB font tables |
   | `vga_attribute_ctrl` | `ega_attribute_ctrl` | readback, Color Select, PEL width, P5/P4 select, panning compatibility, 8-bit DAC address |
   | `vga_dac` | new | 256 x 18 palette, PEL mask, state machine, switch-sense comparator |
   | `vga_plane_ram`, `vga_rom` | EGA | 32 KB ROM, CPU order |

3. Independent model `scripts/vga_model.py` from the documents and the spec
   (same structure as `ega_model.py`).
4. Verification: see [testplan](testplan.md) and [formal plan](formal_plan.md).
5. Report: [final report](../report/final_report.md).

## Interface decisions

The slot side, the bus contract, the frame-capture contract and the debug
ports follow `ibm_ega` exactly; the differences are listed in the spec
("Differences from the EGA slot interface"). The card works with any `clk`
at least as fast as the fastest oscillator enable it is given (spec
"Clocking requirement").
