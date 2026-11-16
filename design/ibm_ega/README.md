# IBM Enhanced Graphics Adapter (EGA)

The IBM Enhanced Graphics Adapter is an 8-bit ISA display card for the IBM
PC, XT and AT. Five custom LSI devices do the work: a CRT controller, a
sequencer, two graphics controllers and an attribute controller. The
display buffer is four bit planes: 64 KB on the card, and up to 256 KB with
the Graphics Memory Expansion Card and Module Kit. A 16 KB BIOS ROM at
C0000h holds the mode-set code and two character fonts, which the BIOS
loads into plane 2. The card drives the IBM Color Display, the Monochrome
Display and the new Enhanced Color Display through a 9-pin direct-drive
connector. It adds 640x350 graphics, 16 colours out of 64, a RAM-loadable
character generator, split screen, smooth scrolling and a light-pen
input, and it keeps the MDA and CGA modes and their programming
interfaces.

## Why it matters

The EGA set the PC graphics standard from 1984 until VGA in 1987. Its
planar memory, the graphics controllers' latches, write modes, set/reset,
bit mask and colour compare, the sequencer's map mask, the attribute
palette and the CRTC register layout carried over almost unchanged into
the VGA and every PC graphics card that followed; the register map at
3C0h-3CFh and 3B4h/3D4h is still emulated today. Its BIOS ROM at C0000h
established the option-ROM video BIOS that the AT system BIOS looks for.

## First introduced

**1984.** IBM announcement letter ENUS184-114, "IBM Enhanced Graphics
Adapter, IBM Graphics Memory Expansion Card, and IBM Graphics Memory
Module", is dated 10 September 1984. InfoWorld reported the product on 8
October 1984. The technical reference modeled here is dated August 2, 1984
and the BIOS ROM 9/13/84. The month of first shipment is not established.

Sources (URLs and SHA-256 in the [specification](spec/spec.md)): IBM,
*IBM Enhanced Graphics Adapter* technical reference, August 2, 1984
([minuszerodegrees.net](https://www.minuszerodegrees.net/oa/OA%20-%20IBM%20Enhanced%20Graphics%20Adapter.pdf);
also in *Options and Adapters Technical Reference* Volume 2 on bitsavers),
with logic diagrams and the BIOS listing; IBM *VGA/XGA Technical Reference*
(1992) for assumptions only; the BIOS ROM 6277356 from the
[86Box ROM set](https://github.com/86Box/roms) checked against MAME's
`6277356.u44`; [MAME](https://github.com/mamedev/mame) `ega.cpp` and
[86Box](https://github.com/86Box/86Box) `vid_ega.c` for behaviour
cross-checks only.

## What is modeled

The original card with 256 KB (expansion card and module kit installed),
as a synthesizable SystemVerilog design with one module per device:

| File | Device |
|---|---|
| [`src/ibm_ega.sv`](src/ibm_ega.sv) | card top: ISA slot, direct-drive monitor port, wiring |
| [`src/ega_crtc.sv`](src/ega_crtc.sv) | CRT controller (25 registers) |
| [`src/ega_sequencer.sv`](src/ega_sequencer.sv) | sequencer |
| [`src/ega_graphics_ctrl.sv`](src/ega_graphics_ctrl.sv) | graphics controller (instantiated as GC 1 and GC 2) |
| [`src/ega_attribute_ctrl.sv`](src/ega_attribute_ctrl.sv) | attribute controller |
| [`src/ega_io_decode.sv`](src/ega_io_decode.sv), [`src/ega_ext_regs.sv`](src/ega_ext_regs.sv) | the card's decode PROMs and external registers |
| [`src/ega_display_fetch.sv`](src/ega_display_fetch.sv) | display fetch and character-generator path |
| [`src/ega_plane_ram.sv`](src/ega_plane_ram.sv), [`src/ega_rom.sv`](src/ega_rom.sv) | display planes and BIOS ROM |

Not modeled: the feature connector (beyond FEAT0/1 and FC0/1), CPU wait
states, DRAM refresh, the 64 KB and 128 KB configurations, analog output.
Everything the technical reference leaves open is a numbered assumption
(E1-E33) in the spec. See the [verification report](report/final_report.md)
for the results.

```sh
sh design/ibm_ega/scripts/run_all.sh     # in the ai-hw-engineer container
```

The ROM is IBM's copyrighted firmware: `scripts/get_rom.py` downloads it
into the ignored `work/firmware/` and checks its hashes. It is never
committed.

- [Specification, interface, register map and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)

Issues: https://github.com/hevangel/ai_hw_engineer/issues/270 (chip set),
https://github.com/hevangel/ai_hw_engineer/issues/271 (card)
