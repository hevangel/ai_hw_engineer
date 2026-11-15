# IBM Enhanced Graphics Adapter (EGA): specification

Status: see [the verification report](../report/final_report.md). This file
is the contract that both the RTL (`src/`) and the independent reference
model (`scripts/ega_model.py`) implement. Everything IBM's document does not
state is a numbered assumption (`E1`...) in the [ledger](#assumptions); the
same tag appears as `ASSUMPTION En` in the RTL and the model.

## Sources

| Ref | Document | Use |
|---|---|---|
| TR | IBM, *IBM Enhanced Graphics Adapter*, technical reference section dated **August 2, 1984** (from the *Options and Adapters Technical Reference*), 174 PDF pages: description, registers (pp. 12-61), BIOS mode tables (pp. 63-68), programming considerations, feature connector, switches, connectors, jumpers, logic diagrams (11 sheets, pp. 87-97; memory expansion card 5 sheets) and the complete BIOS listing (pp. 103 ff., ROM dated 9/13/84). [minuszerodegrees.net copy](https://www.minuszerodegrees.net/oa/OA%20-%20IBM%20Enhanced%20Graphics%20Adapter.pdf), SHA-256 `d2411a689d762e9c6915fd3b15a92f760beada41a4cd1b0020fd29814db151bd` | Primary source. "p.N" below is the printed page number |
| OA2 | IBM, *Technical Reference Options and Adapters Volume 2* (bitsavers file dated Apr84), [bitsavers](https://bitsavers.trailing-edge.com/pdf/ibm/pc/cards/Technical_Reference_Options_and_Adapters_Volume_2_Apr84.pdf), SHA-256 `b5bf24ea3e63082d5c637db8b08469c6d4929b4b9f6b7b24c7a211338b42a15f` | Contains the same EGA section dated August 2, 1984, with the same 9/13/84 listing (OCR search). Volume 1 (SHA-256 `21586244...`) and Volume 3 (`cc2a8393...`, the Professional Graphics Controller) do not. TR is the cleaner scan and is the one cited |
| VGA | IBM, *VGA/XGA Technical Reference Manual*, preliminary draft May 1992, [bitsavers](https://bitsavers.trailing-edge.com/pdf/ibm/pc/cards/IBM_VGA_XGA_Technical_Reference_Manual_May92.pdf), SHA-256 `8e78ac530c53ebdba59008e000b318a04ff6c4bed3d70518a088f415d148dd1d` | IBM's later description of registers the EGA shares. Used only as the basis of assumptions, cited where used |
| ROM | IBM EGA BIOS, part 6277356, U44 (27128, 16 KB). 86Box ROM set `video/ega/ibm_6277356_ega_card_u44_27128.bin`, commit `1ac40f28aa01d2aa159eee81a7bb3eae4b149e9a`; fetched and checked by `scripts/get_rom.py` | Real software: mode parameter table, POST switch-sense code, font tables, font-load and mode-set sequences |
| MAME | MAME `src/devices/bus/isa/ega.cpp` and `src/devices/video/crtc_ega.cpp` (BSD-3-Clause), commit `8be57cdc5f44ab830dff44c06dd39f24190742d4` | Behaviour cross-check only; no code copied |
| 86Box | 86Box `src/video/vid_ega.c`, `vid_ega_render.c` (GPL-2.0), commit `57b10b0a1b9785aa428c94bb6d35c4799079de8e` | Behaviour cross-check only (read, never copied) |

The PDFs and the ROM are not committed. They are downloaded into the
ignored `design/ibm_ega/work/refs/` and `work/firmware/`. Scanned pages were
rendered with pypdfium2 and every register table, schematic pin and listing
byte quoted here was checked on a zoomed rendering, not on the OCR text.

### ROM image

| Item | Value |
|---|---|
| Size | 16,384 bytes; header `55 AA 20` (32 x 512 bytes); 8-bit sum 00h |
| 86Box dump (CPU order) | SHA-256 `bf1583dd387d6e078ab3f5039bcb3f7020a66a63d5f0e57039883c5081dbbf9c`, SHA-1 `3af56105530366669a8905c14439619bf6b76b25`, CRC32 `2f2fbc40` |
| Same bytes in EPROM order (reversed) | SHA-1 `dc0794499b3e499c5777b3aa39554bbf0f2cc19b`, CRC32 `dc146448`: **equal to MAME's `6277356.u44` entry** |
| Sign-on (0005h) | `2400` `6277356 (C)COPYRIGHT IBM 1984` `9/13/84`, identical to listing lines 606-613 (zoomed) |
| VIDEO_PARMS (0717h) | 23 entries x 64 bytes; entry 0 equals listing lines 1787-1819 byte for byte (zoomed) |
| Fonts | 8x14 (`CGMN`) at 2230h, 8x8 double dot (`CGDDOT`) at 3160h (the INT 1Fh vector the POST sets, 3560h, is its upper half) |

Byte order: the logic diagram drives EPROM pins A0-A13 from the *inverted*
address lines (LS04 U45-U47, sheet 4, into U44, sheet 1). CPU offset `a`
reads EPROM location `a XOR 3FFFh`, so the chip image a programmer reads is
the CPU image reversed. That is why MAME's dump is reversed and why MAME
(and 86Box, when it detects `AA 55` at the end) swap it at load time.
`get_rom.py` writes the EPROM-order image; `ega_rom.sv` inverts the address
exactly as the board does.

## The board modeled

IBM Enhanced Graphics Adapter, first version (TR August 1984), with:

- the five custom LSI devices: CRT controller (U32), sequencer (U33), two
  graphics controllers (sheets 6/7), attribute controller (U24);
- the Graphics Memory Expansion Card with the Graphics Memory Module Kit
  installed: **256 KB, four 64 KB planes** (TR p.4). 64 KB/128 KB are not
  modeled (the BIOS 64 KB parameter entries are still checked for geometry);
- the 14.31818 MHz clock from the I/O channel (OSC, B30), the 16.257 MHz
  on-board oscillator U7, and the feature-connector EXT OSC (an input you tie
  off), selected by the LS153 U15 under Miscellaneous Output bits 3-2;
- configuration switch block SW1 (four switches), jumpers P1 (direct-drive
  pin 2: R' or ground) and P3 (I/O at 3XX or 2XX);
- the light-pen interface (P2), the 9-pin direct-drive connector (J3), IRQ 2.

Not modeled: the feature connector (FEAT0/1 are inputs, FC0/FC1 are
exported, nothing else), the 64-pin memory expansion connector as a
separate card, DRAM refresh and CPU/CRT memory-cycle interleaving (wait
states, see E26), the analog/electrical behavior and AC timing.

**Introduced: 1984.** IBM announcement letter ENUS184-114, "IBM Enhanced
Graphics Adapter, IBM Graphics Memory Expansion Card, and IBM Graphics
Memory Module", is dated 10 September 1984; InfoWorld (8 October 1984)
reported the product in October 1984. The TR is dated August 2, 1984 and
the ROM 9/13/84. The exact month of first shipment is not established.

## Architecture

One clock domain `clk`; every input is sampled on `clk`; the oscillators
are clock-enable inputs. Synchronous active-low `rst_n` is the
simulation/FPGA power-on reset (all registers zero, E1). The slot's RESET DRV
is a separate input that does what sheets 1, 3 and 9 show.

| File | Device (TR sheet) | Contents |
|---|---|---|
| `ibm_ega.sv` | card | slot and monitor ports, data-bus mux, wiring |
| `ega_io_decode.sv` | U16 + PROM U34 + LS138 U25/U28, PROM U48 (sheet 4) | I/O and memory decode |
| `ega_ext_regs.sv` | U37, U49, U35, U15, U18 (sheet 9) | Misc Output, Feature Control, Input Status 0/1 card bits, switch sense, light-pen flip-flop |
| `ega_sequencer.sv` | U33 (sheet 2) | 5 registers, dot/character clock, CPU plane address and map-mask/odd-even plane enables, character-generator map select |
| `ega_crtc.sv` | U32 (sheet 3) | 25 registers, counters, timing, display address, cursor/underline, line compare, light-pen latch, vertical interrupt |
| `ega_graphics_ctrl.sv` | GC 1 and GC 2 (sheets 6/7), one instance each | 9 registers + position, write path, read path, latches, serializer for two planes |
| `ega_display_fetch.sv` | sheet 5 / latches | character pipeline: display fetch, font fetch, 2-character pipeline, pixel-index formation |
| `ega_attribute_ctrl.sv` | U24 (sheet 8) | 20 registers + flip-flop, panning, plane enable, palette, border, blink |
| `ega_plane_ram.sv` | display buffer | one 64 KB plane: CPU read/write port, display read port, debug port |
| `ega_rom.sv` | U44 | 16 KB ROM, `$readmemh(ROM_FILE)`, inverted address |

The four plane RAMs and the ROM are instantiated in `ibm_ega.sv` behind
plain synchronous ports, so an FPGA wrapper can replace `ega_plane_ram` /
`ega_rom` with block RAM or move them outside.

## Interface (`ibm_ega`)

| Parameter | Default | Meaning |
|---|---|---|
| `ROM_FILE` | `""` | `$readmemh` image of the EPROM in chip order (`work/firmware/ega_u44_chip.hex` from `get_rom.py`). Empty: ROM reads 00h |

| Port | Dir | Meaning |
|---|---|---|
| `clk` | in | Design clock. Must run at least as fast as the fastest oscillator enable |
| `rst_n` | in | Synchronous power-on reset of all card state (simulation/FPGA), not a slot pin |
| `reset_drv_i` | in | Slot B2 RESET DRV, active high. Clears Misc Output and Feature Control (U37/U49 CLR) and holds the CRTC reset (E2) |
| `a_i[19:0]` | in | Slot A19-A0 |
| `d_i[7:0]` | in | Slot D7-D0 into the card |
| `d_o[7:0]`, `d_oe_o` | out | Data the card drives and its enable (I/O read of a readable port, memory read of the ROM or the enabled RAM window) |
| `ior_n_i`, `iow_n_i`, `memr_n_i`, `memw_n_i` | in | -IOR, -IOW, -MEMR, -MEMW |
| `aen_i` | in | AEN; high disables I/O decode (U16) |
| `dack0_n_i` | in | Slot B19 (-DACK0 on the PC/XT; on the AT this pin is -REFRESH). Low disables the memory decode PROM U48 (G1) |
| `irq2_o`, `irq2_oe_o` | out | Slot B4 "IRQ 2" (on the AT this pin is IRQ 9): vertical-interrupt latch and its driver enable (E9) |
| `iochrdy_o`, `iochrdy_oe_o` | out | Slot A10 I/O CH RDY. The card has the driver (LS125 U9 from the sequencer RDY); this model never inserts wait states: `iochrdy_oe_o` is always 0 (E26) |
| `osc14_ce_i` | in | One pulse per period of the slot's 14.31818 MHz OSC (B30) |
| `osc16_ce_i` | in | One pulse per period of the on-board 16.257 MHz oscillator U7 |
| `ext_osc_ce_i` | in | Feature-connector EXT OSC (tie to 0) |
| `sw_i[3:0]` | in | Configuration switches SW1..SW4 as `sw_i[0]`..`sw_i[3]`; 1 = off (open), 0 = on (closed) |
| `p1_i` | in | Jumper P1: 1 = pins 1-2 (R' on direct-drive pin 2, Enhanced Color Display), 0 = pins 2-3 (pin 2 grounded) |
| `p3_i` | in | Jumper P3: 1 = pins 1-2 (I/O at 3XX, normal), 0 = pins 2-3 (2XX) |
| `feat_i[1:0]` | in | Feature connector FEAT 0/FEAT 1 (Input Status 0 bits 5/6). Feature connector not modeled; tie off (E25) |
| `fc_o[1:0]` | out | Feature Control register bits 1-0 as written (the schematic takes them from LS175 Q-bar outputs to pins 17/19, E25) |
| `lpen_n_i` | in | P2 pin 1 -LPEN IN; a falling edge sets the light-pen flip-flop |
| `lpen_sw_n_i` | in | P2 pin 3 -LPEN SW (0 = switch closed), read as Input Status 1 bit 2 |
| `pix_en_o` | out | One pulse per dot clock; the outputs below hold that dot while it is high |
| `video_o[5:0]` | out | Direct-drive color bits {R', G'/I, B'/V, R, G, B} = palette bit order 5..0. Bit 5 is forced 0 when `p1_i` = 0 (pin 2 grounded) |
| `hsync_o`, `vsync_o` | out | Direct-drive pins 8/9: horizontal/vertical retrace XOR Misc Output bits 6/7 (LS86 U8) |
| `video_oe_o` | out | LS244 U36 enable: 0 when Misc Output bit 4 disables the internal video drivers |
| `blank_o`, `de_o` | out | Simulation aids: composite blank and (skewed) display enable of the dot |
| `dbg_reg_addr_i[7:0]`, `dbg_reg_data_o[7:0]` | in/out | Simulation-only, side-effect-free register read (map below) |
| `dbg_plane_i[1:0]`, `dbg_mem_addr_i[15:0]`, `dbg_mem_data_o[7:0]` | in/out | Simulation-only, side-effect-free plane memory read |

### Bus timing

All slot inputs are sampled every `clk`. A write (I/O or memory) takes
effect at the rising edge of -IOW/-MEMW, with the address and data sampled
in the last clock the strobe was low. A read drives `d_o`/`d_oe_o` while the
strobe is low (valid from the second clock of the strobe); its side effects
(attribute flip-flop reset, processor latch load) happen at the rising edge.
`tb/ega_tb.cpp` drives: address/AEN stable, strobe low for 2 clocks, strobe
high, 2 idle clocks.

### Frame-capture contract

A host rebuilds the picture by sampling, on every `clk` where `pix_en_o` is
1: `video_o[5:0]`, `hsync_o`, `vsync_o` (and optionally `blank_o`, `de_o`).
Each such sample is one dot. Dots are produced only while the sequencer runs
(reset register = 3) and the selected clock source pulses. A line starts at
the dot after a falling edge of the retrace signal (after polarity is
removed); the dot rate is the selected oscillator, divided by 2 when
Clocking Mode bit 3 is 1. `tb/ega_tb.cpp` records exactly this as a
run-length list, and `scripts/bios_modes.py` measures geometry from it.

### Debug register map (`dbg_reg_addr_i`, simulation only)

| Addr | Contents | Addr | Contents |
|---|---|---|---|
| 00-04 | sequencer registers 0-4 | 05 | sequencer index |
| 10-28 | CRTC registers 00-18h | 29 | CRTC index |
| 2A/2B | light-pen high/low | 30-38 | graphics registers 0-8 (GC 1 copy) |
| 39 | graphics index | 3A/3B | GC 1/GC 2 position |
| 40-53 | attribute registers 00-13h | 54 | attribute index (bit 5 = palette address source) |
| 55 | attribute flip-flop (1 = next write is data) | 60 | Misc Output |
| 61 | Feature Control | 62-65 | processor latches, planes 0-3 |
| 66 | light-pen flip-flop | 67 | vertical-interrupt latch |
| 68 | blink frame counter (5 bits) | other | FFh |

## I/O and memory decode (sheets 1 and 4)

The I/O decode uses only A9-A0: U16 (LS27) gives `!AEN & A9 & (P3 ? A8 :
!A8)` to PROM U34 together with Misc Output bit 0 (MONO MONITOR) and A7-A0.
**A15-A10 are not decoded, so every port repeats every 400h** (for example
3D4h, 7D4h, 0BD4h ... and 0FFD4h all reach the CRTC address register). U34's
contents are not printed; the decoded ports below are those TR documents
(E3). `x` = B when Misc Output bit 0 is 0, D when it is 1; with P3 at 2XX
the first digit is 2.

| Port | Write (LS138 U25) | Read (LS138 U28) |
|---|---|---|
| 3C0 | ATRIOW: attribute address/data (flip-flop) | not decoded |
| 3C2 | MODE IOW: Miscellaneous Output | STATUS: Input Status 0 |
| 3C4 / 3C5 | SEQIOW: sequencer address / data (A0) | not decoded |
| 3CA | GRAPHIC: GC 2 position | not decoded |
| 3CC | GRAPHIC: GC 1 position | not decoded |
| 3CE / 3CF | GRAPHIC: GC 1+2 address / data | not decoded |
| 3x4 / 3x5 | CRTIOW: CRTC address / data (A0) | CRTIOR: 3x5 only (E4) |
| 3xA | FCIOW: Feature Control | ATRIOR: Input Status 1, resets the attribute flip-flop |
| 3xB | LP CLR: clear light-pen flip-flop (E5) | not decoded |
| 3xC | LP SET: preset light-pen flip-flop (E5) | not decoded |

Memory decode (PROM U48, disabled while `dack0_n_i` is low):
- ROM: C0000h-C3FFFh, reads only (ROMCE = -MEMR OR -ROM VALID, U17).
- RAM: only when Misc Output bit 1 (Enable RAM) is 1, in the window chosen by
  Graphics Miscellaneous bits 3-2: 00 = A0000h-BFFFFh (128 KB), 01 =
  A0000h-AFFFFh, 10 = B0000h-B7FFFh, 11 = B8000h-BFFFFh.

## Registers

"W" = write only, "R/W", "R" = read only, as TR states. Reading a
write-only register returns nothing from the device: the card's data bus has
pull-ups (resistor module U38 on BD0-BD7, sheet 1), so undriven bits read 1
(E4).

| Group | Port | Index | Register | Access | Fields used |
|---|---|---|---|---|---|
| External | 3C2 | - | Miscellaneous Output | W | 0 I/O select (0 = 3Bx), 1 Enable RAM, 3-2 clock select (00 14 MHz, 01 16 MHz, 10 EXT, 11 none), 4 disable internal video drivers, 5 page bit for odd/even, 6 HSYNC polarity, 7 VSYNC polarity (1 = negative) |
| | 3xA | - | Feature Control | W | 1-0 to the feature connector |
| | 3C2 | - | Input Status 0 | R | 4 switch sense, 5/6 FEAT0/1, 7 CRT interrupt (E9); 3-0 read 1 (E4) |
| | 3xA | - | Input Status 1 | R | 0 display inactive (E10), 1 light-pen strobe, 2 light-pen switch, 3 vertical retrace, 5-4 diagnostic (E11); 7-6 read 1 |
| Sequencer | 3C4 | - | Address | W | 3-0 |
| | 3C5 | 00 | Reset | W | 0 asynchronous reset (0 = clear and halt), 1 synchronous reset |
| | | 01 | Clocking Mode | W | 0 8/9 dots (1 = 8), 1 bandwidth, 2 shift load, 3 dot clock /2 |
| | | 02 | Map Mask | W | 3-0 plane write enables |
| | | 03 | Character Map Select | W | 1-0 map B (attr bit 3 = 0), 3-2 map A (attr bit 3 = 1) |
| | | 04 | Memory Mode | W | 0 alpha, 1 extended memory, 2 odd/even (0 = odd/even) |
| CRTC | 3x4 | - | Address | W | 4-0 |
| | 3x5 | 00 | Horizontal Total | W | characters - 2 |
| | | 01 | Horizontal Display End | W | displayed characters - 1 |
| | | 02 | Start Horizontal Blank | W | 8 bits |
| | | 03 | End Horizontal Blank | W | 4-0 end, 6-5 display enable skew |
| | | 04 | Start Horizontal Retrace | W | 8 bits |
| | | 05 | End Horizontal Retrace | W | 4-0 end, 6-5 retrace delay, 7 start odd memory address |
| | | 06 | Vertical Total | W | bits 7-0 of 9 |
| | | 07 | Overflow | W | 0 VT8, 1 VDE8, 2 VRS8, 3 VBS8, 4 LC8, 5 cursor location bit 8 (E21) |
| | | 08 | Preset Row Scan | W | 4-0 |
| | | 09 | Maximum Scan Line | W | 4-0 |
| | | 0A | Cursor Start | W | 4-0 |
| | | 0B | Cursor End | W | 4-0 end, 6-5 cursor skew |
| | | 0C/0D | Start Address High/Low | R/W | 16 bits |
| | | 0E/0F | Cursor Location High/Low | R/W | 16 bits |
| | | 10 | Vertical Retrace Start (W) / Light Pen High (R) | W / R | |
| | | 11 | Vertical Retrace End (W) / Light Pen Low (R) | W / R | 3-0 end, 4 clear vertical interrupt (0 = clear), 5 enable vertical interrupt (0 = enable) |
| | | 12 | Vertical Display End | W | bits 7-0 of 9 |
| | | 13 | Offset | W | row-to-row address step / 2 |
| | | 14 | Underline Location | W | 4-0 |
| | | 15 | Start Vertical Blank | W | bits 7-0 of 9 |
| | | 16 | End Vertical Blank | W | 4-0 |
| | | 17 | Mode Control | W | 0 CMS0, 1 select row scan counter, 2 HRTC/2, 3 count by two, 4 output control, 5 address wrap, 6 byte mode, 7 hardware reset |
| | | 18 | Line Compare | W | bits 7-0 of 9 |
| Graphics | 3CC / 3CA | - | GC 1 / GC 2 Position | W | 1-0 |
| | 3CE | - | Address | W | 3-0 |
| | 3CF | 00 | Set/Reset | W | 3-0 |
| | | 01 | Enable Set/Reset | W | 3-0 |
| | | 02 | Color Compare | W | 3-0 |
| | | 03 | Data Rotate | W | 2-0 count, 4-3 function (00 none, 01 AND, 10 OR, 11 XOR) |
| | | 04 | Read Map Select | W | 2-0 |
| | | 05 | Mode | W | 1-0 write mode, 2 test condition, 3 read mode, 4 odd/even, 5 shift register |
| | | 06 | Miscellaneous | W | 0 graphics, 1 chain odd/even, 3-2 memory map |
| | | 07 | Color Don't Care | W | 3-0 (E15) |
| | | 08 | Bit Mask | W | 7-0 |
| Attribute | 3C0 | - | Address | W | 4-0 index, 5 palette address source |
| | 3C0 | 00-0F | Palette | W | 5-0 {R', G'/I, B'/V, R, G, B} |
| | | 10 | Mode Control | W | 0 graphics, 1 monochrome attributes, 2 line graphics, 3 blink |
| | | 11 | Overscan Color | W | 5-0 |
| | | 12 | Color Plane Enable | W | 3-0 plane enables, 5-4 video status mux |
| | | 13 | Horizontal Pel Panning | W | 3-0 |

TR misprints the Horizontal Pel Panning index as 12h on p.60; its register
table on p.56 and the BIOS (P_HPEL EQU 13H, listing line 552) give 13h.

## Behavior

### Clocks (sheet 2, sequencer p.19-20)

A **master pulse** is a `clk` with the selected oscillator enable high
(Misc Output bits 3-2: 00 `osc14_ce_i`, 01 `osc16_ce_i`, 10 `ext_osc_ce_i`,
11 none: U15 input 1C3 is not connected). The sequencer runs when Reset
register bits 1-0 are 11. While it is halted there are no dots, the dot
counter and the /2 phase are 0, and the CRTC does not advance (E6). When it
runs, every master pulse is a dot if Clocking Mode bit 3 is 0; if it is 1,
every second master pulse is a dot, starting with the first (E7). A
character is 9 dots when Clocking Mode bit 0 is 0, else 8. The first dot of
each character is a **character boundary**.

### CRTC timing (pp.25-44)

The CRTC has a horizontal character counter `hc` (0 .. HT+1, HT+2
characters per line, p.25) and a vertical line counter `vc` (0 .. VT+1,
VT+2 lines per frame, E8), a row scan counter `rs`, a row start address and
a memory address counter `ma`. At each character boundary it first produces
the flags of the current character, then advances:

- display enable: `hc <= HDE` and `vc <= VDE` (VDE 9 bits);
- horizontal blank: on at `hc == SHB`; stays on until a later character
  with `hc[4:0] == EHB[4:0]` (that character is not blanked). Width is
  `(EHB - SHB) mod 32`, 0 meaning 32 (p.27 algorithm, E12). Horizontal
  retrace the same with SHR/EHR. Vertical blank and retrace the same per
  line with VBS/VBE (5 bits) and VRS/VRE (4 bits);
- the line advances at the character where horizontal retrace starts
  (`hc == SHR`), every time or every second time when Mode Control bit 2 is
  1 (E13). At the advance: if `vc == VT+1` the frame restarts (`vc = 0`, `rs`
  = Preset Row Scan, row start = Start Address); otherwise `vc` increments,
  and `rs` wraps to 0 after Maximum Scan Line (adding 2 x Offset to the row
  start) or increments. When the line being left equals Line Compare, the
  row start becomes 0 instead (screen B, p.74; E14);
- `ma` = row start (+1 when End Horizontal Retrace bit 7 is 1) at `hc = 0`,
  then +1 per character, or per two characters when Mode Control bit 3 is 1;
- the display address is `ma` through the output multiplexer of p.43: word
  mode (bit 6 = 0) shifts left one and puts MA13 or MA15 (bit 5) into bit 0;
  then bit 13 is replaced by `rs[0]` when bit 0 = 0 and bit 14 by `rs[1]` when
  bit 1 = 0;
- cursor: `ma == cursor location` and `CS <= rs < CE` (E16); underline row:
  `rs == UL` (E16);
- Mode Control bit 7 = 0 forces both retrace outputs to 0 (counters run).

The vertical interrupt latch is set when vertical retrace starts, if VRE
bit 5 = 0 and bit 4 = 1; it is held clear while bit 4 = 0 (p.37, p.72-73).
The light-pen registers capture `ma` at the first character boundary after
the light-pen flip-flop rises. RESET DRV holds the counters and the
interrupt latch at 0 (E2).

### Display pipeline and attribute controller

At each character boundary the card fetches the four plane bytes at the
display address (`[15:14]` forced 0 unless Memory Mode bit 1 is set). If
Graphics Miscellaneous bit 0 is 0 (alpha), the plane 2 byte is instead read
at the character-generator address `{map, 0, char, rs}` (char = plane 0
byte, map from Character Map Select, p.22-23, E17). The fetch enters a
two-character pipeline (E18). The character displayed at boundary `k` is the
one fetched at `k-2`; its pixel indices are formed at boundary `k` with the
current register values:

- Attribute Mode bit 0 = 1 (graphics): index of dot `j` =
  `{C3,C2,C1,C0}` from the serializers (GC Mode bit 5 = 0: bit `7-j` of each
  plane; = 1: two-bit pairs, plane 0 then 1 for C1/C0, planes 2/3 for
  C3/C2, p.52 and CGA format p.8; Clocking Mode bit 2: E19); a 9th dot is 0.
  When Graphics Miscellaneous bit 0 = 0 the attribute byte's low nibble is
  used for every dot instead. With blink enabled, index bit 3 is forced 1 in
  the blink-off phase (E20).
- bit 0 = 0 (alphanumeric): glyph bit `7-j` of the font byte; the 9th dot is
  the 8th when Mode bit 2 = 1 and the character is C0h-DFh, else background
  (p.58). Foreground = attribute bits 3-0; background = bits 6-4, plus bit 7
  when blink is disabled. Blink enabled and attribute bit 7 = 1: background
  in the blink-off phase. Monochrome attributes (bit 1) and the underline row
  and attribute `x000x001`: foreground over the whole character (E22). Cursor
  (delayed by cursor skew) in the cursor-on phase: foreground (E23).

Every dot: horizontal pel panning shifts left by 0-7 (8-dot) or by 0-8 using
the sequence 8,0,1,...,7 (9-dot), taking dots from the next character
(p.61, E24). The index is ANDed with Color Plane Enable bits 3-0 and looks
up the palette. Output = 0 when blanked; the overscan color when display
enable is off or when the attribute address bit 5 is 0 (E27); otherwise the
palette entry. Display enable at boundary `k` is the counter flag of
boundary `k-1-skew` (End Horizontal Blank bits 6-5), so the BIOS skew of 1
aligns it with the two-character data pipeline (E18). Blank and vertical
retrace leave through the same two-character pipeline; horizontal retrace
is additionally delayed by End Horizontal Retrace bits 6-5.

The blink counter (5 bits) increments at each start of vertical retrace:
characters blink with bit 4 and the cursor with bit 3 (E23).

### Processor memory access (pp.20-23, 47-55)

Offset `o` into the RAM window. Plane address: when Graphics Miscellaneous
bit 1 (chain) is 1, `{o[15:1], X}` where X = `o[16]` for the 128 KB map and
NOT Misc Output bit 5 otherwise (E28); else `o[15:0]` (`o[16]` ignored in the
128 KB map). Bits 15-14 are 0 unless Memory Mode bit 1 is 1. A write goes to
the planes enabled by Map Mask, restricted to planes 0/2 (even `o`) or 1/3
(odd `o`) when Memory Mode bit 2 = 0.

Write data per plane `p` (bit index `n` = 2 x position + plane-in-chip):

| Write mode | Data before the function | Function and bit mask |
|---|---|---|
| 0 | CPU byte rotated right by the count; replaced by 8 x Set/Reset bit `n` when Enable Set/Reset bit `n` = 1 | function with the latch, then `(f & mask) | (latch & ~mask)` |
| 1 | the latch | none (latch written) |
| 2 | 8 x CPU data bit `n` | function with the latch, then bit mask |
| 3 | not valid: nothing is written (E29) | |

A read loads all four latches from the plane address. Read mode 0 returns
the latch of plane `Read Map Select` (with GC Mode bit 4: `{rms[2:1], o[0]}`);
read mode 1 returns 1 in each bit where every plane with Color Don't Care
= 1 equals its Color Compare bit (E15). Each graphics controller drives the
bits of its own planes; planes 4-7 select no controller, which reads FFh
(E30).

## Assumptions

| Tag | Assumption | Basis | Checked by |
|---|---|---|---|
| E1 | `rst_n` clears every register, latch, counter and flip-flop to 0 (GC positions both 0, sequencer halted) | Power-on state is not documented | Directed `power_on` |
| E2 | RESET DRV (synchronously sampled) holds Misc Output and Feature Control at 0 (sheet 9 CLR), and holds the CRTC counters, pipeline flags and interrupt latch at 0. CRTC and other registers keep their values | Sheet 3 wires RESET to the CRTC RESET pin; what it resets is not described | `reset_drv` |
| E3 | The I/O decode PROM U34 decodes exactly the TR ports listed above, fully on A7-A0; nothing else in 3C0-3CF/3x0-3xF responds | U34 contents not printed. A7-A0, MONO and the U16 output are its only inputs (sheet 4) | `io_decode_aliases`, formal |
| E4 | Readable ports: 3C2, 3xA, 3x5. A read of 3x5 with an index other than 0C-11h, and Input Status bits no device drives (ISR0 3-0, ISR1 7-6), read 1 | Only three read strobes exist (U28); the BD bus pull-ups U38 | `registers_readback` |
| E5 | LP CLR is port 3xB and LP SET is 3xC | U25 has LP SET/LP CLR outputs; the BIOS light-pen routine clears at ADDR_6845+7 = 3xB (listing line 3264). 3xC follows the CGA/MDA convention | `light_pen` |
| E6 | Sequencer halted (Reset bits 1-0 != 11): no dots, CRTC frozen, dot phase cleared. Asynchronous reset (bit 0 = 0) also clears Character Map Select (p.23). CPU memory access is unaffected | p.19 "clear and halt" | `sequencer_reset` |
| E7 | With Clocking Mode bit 3, the first master pulse after the sequencer starts is a dot | Not stated | `dot_clock_div2` |
| E8 | VT+2 lines per frame. Vertical display end: lines 0..VDE are displayed | VGA p.2-61 ("minus 2"). It gives the CGA (262) and MDA (370) frame lengths for the BIOS values 104h and 170h | BIOS geometry |
| E9 | The vertical interrupt latch drives IRQ 2 high when set; Input Status 0 bit 7 reads the latch (1 = interrupt pending). `irq2_oe_o` = NOT VRE bit 5 | CRTINT is wired straight to slot B4 and to ISR0 bit 7 (sheets 1, 9); PC IRQs are active high. TR p.15 text says the opposite polarity; VGA p.2-44 agrees with the wiring | `vertical_interrupt` |
| E10 | Input Status 1 bit 0 is 1 while display enable is off | TR p.16 text says 0 means retrace; VGA p.2-45 says 1 means retrace, and the EGA BIOS waits with `TEST AL,1` CGA-style (C000:1719) | `status_bits` |
| E11 | Video status mux: 00 → bit 5 R, bit 4 B; 01 → bit 5 B', bit 4 G; 10 → bit 5 R', bit 4 G'; 11 → both 0. Sampled from the last dot output | TR p.17/p.60 table; 11 "not used" | `status_bits` |
| E12 | End compares start on the character after the start match; equal low bits give the maximal width | p.27/29/37/40 algorithms; MDA mode 7 VRS=15Eh, VRE=2Eh needs a 16-line retrace | geometry |
| E13 | The vertical counter advances where horizontal retrace starts (`hc == SHR`) | p.32 "row scan counter increments each horizontal retrace"; p.42 bit 2 "HRTC ... clock that controls the vertical timing counter" | all video tests |
| E14 | Line compare: the line after the one with `vc == LC` starts at address 0; the row scan counter is not reset | p.43-44, p.74 | `split_screen` |
| E15 | Color Don't Care bit = 1 means the plane takes part in the compare | TR p.54 says "1 = don't care"; VGA p.2-87 says "When set to 1, the bits in that map are compared", and the BIOS loads 0Fh in every graphics mode | `read_mode1` |
| E16 | Rows are numbered from 1 in TR's "one less than" phrases: cursor on rows CS <= rs < CE (none if CS >= CE); underline on rs == UL; row scan wraps after rs == MSL | TR p.32-33, p.39. A literal 0-based reading would put mode 7's underline (UL = 0Dh, 14 rows) outside the character | `cursor_shapes`, BIOS text |
| E17 | Character map: `A` when attribute bit 3 = 1, Memory Mode bits 1 and 0 are 1 and A != B; else `B` if Memory Mode bit 1 = 1, else map 0. Map `n` is at plane 2 offset `n x 16 KB` | p.22-23 table, p.69 figure (+0K/+16K/+32K/+48K) | `char_map_select` |
| E18 | Data pipeline: the character displayed at boundary `k` was fetched at boundary `k-2`. Display enable at `k` is the counter flag of boundary `k-1-skew`, so the skew of 1 that the BIOS programs in every mode with more than 64 KB aligns display enable with the data; cursor uses `k-2-cursor skew` (BIOS 0 aligns); blank and vertical retrace use `k-2`; horizontal retrace `k-2-delay` | p.28: skew compensates the fetch, character generator and panning pipeline; its depth is not given | p.28: skew compensates the fetch/character generator/panning pipeline; the depth is not given | `skew` |
| E19 | Shift Load (Clocking bit 2): GC chips output their even plane's byte on characters with even `hc` and their odd plane's byte on odd `hc`, on the even color output; odd color outputs are 0 | p.20 "loaded every other character clock ... 16 bits ... chained" | `shift_load` |
| E20 | Graphics blink: in the blink-off phase index bit 3 is forced to 1 | Makes the BIOS mode F palette (TR p.67-68) give black/video/blinking/intensified as p.9 states | `graphics_blink` |
| E21 | Overflow bit 5 ("cursor location bit 8", p.31) has no effect: the cursor location is 16 bits | The cursor location registers already hold 16 bits | written in random tests |
| E22 | Monochrome underline: attribute bits 6-4 = 000 and 2-0 = 001, only with Attribute Mode bit 1 = 1 | p.75 compatibility table; p.58 "IBM Monochrome Display attributes" | `underline` |
| E23 | Blink counter 5 bits at vertical retrace start; characters visible while bit 4 = 0; cursor shown while bit 3 = 0; cursor = foreground over all dots of the character; not shown in graphics mode | MDA/CGA convention (the TR does not give rates) | `blink_cursor` |
| E24 | Panning values 9-15 shift 0 (9-dot); 8-dot uses bits 2-0 | p.61 gives only the documented sequences | `panning` |
| E25 | `feat_i` is read as is (tie 2'b11 for an empty feature connector: floating TTL inputs). `fc_o` is the register value | Feature connector not modeled | `power_on` |
| E26 | No CPU wait states: every slot access completes in the bench's 2-clock strobe. The bandwidth bit, CRTC output control and GC test condition are stored and have no effect | Memory arbitration is internal to the sequencer and not documented | - |
| E27 | Attribute address bit 5 = 0: dots outside blanking show the overscan color; palette writes are accepted only while bit 5 = 0 | p.57 "bit 5 must be cleared to 0 when loading the palette; set to 1 to enable memory data to access the palette" | `palette_source` |
| E28 | Chain odd/even replaces A0 by A16 (128 KB map) or by NOT Misc Output bit 5 | Sheet 4 LS151 U29 inputs A0, A14, A16, PGSEL; the BIOS sets bit 5 = 1 in every mode while the CRTC fetches even plane addresses, so bit 5 = 1 must give plane address bit 0 = 0 | BIOS text replay |
| E29 | Write mode 3 writes nothing | p.51 "not valid" | `write_modes` |
| E30 | Read Map Select 4-7 (no controller selected) reads FFh; two controllers with the same position combine by AND | Bus pull-ups; positions are a BIOS-fixed hierarchy | `gc_position` |
| E31 | Switch sense: Clocking select k reads switch SW(4-k) (00 → SW4 ... 11 → SW1); closed reads 0 | The listing's POST (C000:009B) builds INFO_3 bit 3 from clock select 00 and bit 0 from 11, and p.15 states bit 3 = switch 4, bit 0 = switch 1 | `switch_sense`, BIOS POST replay |
| E32 | 9-dot graphics: the 9th dot index is 0 | Not stated | random |

## BIOS usage

`VIDEO_PARMS` (0717h) has 23 entries of 64 bytes: columns, rows, points,
page length (word), sequencer 1-4, Misc Output, CRTC 00-18h, attribute
00-13h, graphics 0-8. Entries 0-10h are modes 0-10h (8-0Ch reserved; 0Bh/0Ch
are the font-load register sets for color/monochrome), 11h/12h are modes F
and 10h with more than 64 KB, 13h-16h modes 0-3 on the Enhanced Color
Display (MAKE_BASE, listing lines 2422-2475). SET_REGS (lines 2479-2587)
writes: 3C4/3C5 index 0 = 01h; indices 1-4; 3C2; index 0 = 03h; CRTC 0-18h;
`IN` Input Status 1; attribute pairs 0-13h; 3CC = 0; 3CA = 1; graphics 0-8.

## Disagreements between TR and the emulators

| Item | TR | MAME | 86Box | This model |
|---|---|---|---|---|
| Input Status 0 bit 7 | 1 = video displayed (p.15) | 1 = no IRQ (follows TR) | not set | 1 = interrupt pending (E9, wiring) |
| ISR1 bit 0 | 0 = retrace (p.16) | 0 = retrace (comment) | toggles bits | 1 = display off (E10) |
| Color Don't Care | 1 = don't care (p.54) | - | 1 = compare | 1 = compare (E15) |
| Video status mux 01/10 | 01: bit5 B', bit4 G; 10: bit5 R', bit4 G' | 01: bit5 G, bit4 B'; 10: bit5 G', bit4 R' | 01/10 swapped differently | TR table (E11) |
| ROM image | CPU sees 55AA at C0000 | stores reversed dump, reverses at load | accepts either | EPROM order + inverted address (wiring) |
| Vertical total | "number of scans" (p.30) | `vert_total + 1` | `+2` | +2 (E8) |
| Input Status 0 bits 3-0 | not used | 0 | 0 | 1 (pull-ups, E4) |

## Not modeled

The feature connector (other than FEAT0/1 in and FC0/1 out), CPU wait states
and DRAM cycle interleaving, DRAM refresh, the 64 KB and 128 KB memory
configurations, the 2XX I/O position beyond its decode, analog and AC
timing, the BIOS's 64 KB-only chained display formats beyond the register
semantics above, and interlace (the EGA has none).
