# IBM PS/2 Display Adapter (ISA VGA): specification

Status: see [the verification report](../report/final_report.md). This file
is the contract that both the RTL (`src/`) and the independent reference
model (`scripts/vga_model.py`) implement. Everything IBM's documents do not
state is a numbered assumption (`V1`...) in the [ledger](#assumptions); the
same tag appears as `ASSUMPTION Vn` in the RTL and the model. The card plugs
into the same 8-bit slot contract as [`ibm_ega`](../../ibm_ega/spec/spec.md)
(see [Differences from the EGA slot interface](#differences-from-the-ega-slot-interface)).

## Sources

| Ref | Document | Use |
|---|---|---|
| HITR | IBM, *Personal System/2 Hardware Interface Technical Reference* (May 1988), section "Video Subsystem (Type 1)", printed pages 1-106 (PDF pages 395-500). [bitsavers](https://bitsavers.trailing-edge.com/pdf/ibm/pc/ps2/Personal_System_2_Hardware_Interface_Technical_Reference_May88.pdf), SHA-256 `542242238abd3d5d9657a3cc7c256c2b2d78af986a707e370e4d1aa57c0482af` | Primary source for the original (Type 1) VGA: registers, 3C3, POS, DAC, display connector, signal timing figures 99-104. "HITR p.N" = printed page of that section |
| VGAXGA | IBM, *VGA/XGA Technical Reference Manual*, preliminary draft May 1992, section 2 "VGA Function". [bitsavers](https://bitsavers.trailing-edge.com/pdf/ibm/pc/cards/IBM_VGA_XGA_Technical_Reference_Manual_May92.pdf), SHA-256 `8e78ac530c53ebdba59008e000b318a04ff6c4bed3d70518a088f415d148dd1d` | Same register chapter with bit-level figures (cited "p.2-N"); its notes on the later *Type 2* subsystem are not applied. Section 4 repeats the timing set #1 of HITR |
| BIOSTR | IBM, *PS/2 and PC BIOS Interface Technical Reference* (April 1987), [bitsavers](https://bitsavers.trailing-edge.com/pdf/ibm/pc/ps2/PS2_and_PC_BIOS_Interface_Technical_Reference_Apr87.pdf), SHA-256 `950f2a5508f7092a7eaf0f6181464bc21d0d39e59a9bb63f02ee86ac8668cff2` | INT 10h functions the Unicorn run calls (AH=00h mode set, AH=12h BL=32h video enable) |
| M50 | IBM, *PS/2 Model 50 Technical Reference* (May 1988), SHA-256 `4de65c775d874c6690a0fa7284ecfa184022bbada1bdd8fea36867817484d46f` | Searched for 3C3/46E8/sense; it defers video to HITR. Not otherwise used |
| EGA | the EGA design in this repository (`design/ibm_ega`, IBM EGA TR August 2, 1984) | The VGA is a register superset; where IBM's VGA documents are silent and the EGA TR documents the same function, the EGA ledger entry is reused and cited |
| ROM | IBM PS/2 Display Adapter BIOS, sign-on `...8222554 (C)COPYRIGHT IBM Corp. 1984, 1986 10/27/86`, 24 KB. 86Box ROM set `video/vga/ibm_vga.bin`, commit `1ac40f28aa01d2aa159eee81a7bb3eae4b149e9a`; fetched and checked by `scripts/get_rom.py` | Real software: mode parameter table, POST (sense, timing, memory, DAC tests), INT 10h |
| MAME | MAME `src/devices/bus/isa/vga.cpp` (BSD-3-Clause), commit `8be57cdc5f44ab830dff44c06dd39f24190742d4` | ROM hash cross-check (entry `ibm-vga.bin`), behaviour cross-check only; no code copied |
| 86Box | 86Box `src/video/vid_vga.c`, `vid_svga.c` (GPL-2.0), commit `57b10b0a1b9785aa428c94bb6d35c4799079de8e` | Behaviour cross-check only: read, never copied (46E8/102h handling, switch-sense threshold) |

The PDFs and the ROM are not committed: they live in the ignored
`design/ibm_vga/work/refs/` and `work/firmware/`. Text was extracted with
pypdfium2; register figures were read from the text layer and the HITR scan.

### ROM image

| Item | Value |
|---|---|
| 86Box file | 32,768 bytes, SHA-256 `51b49761f72780a696c36f3d2e74a8168c1c99b865070f7f90b8e621a8b5ae17`, SHA-1 `7b8b0e22ecd002d43d5ed1bb9f9a63d9b9948032`, CRC32 `03b3f90d`. Bytes 0000-1FFFh are 00; the option ROM starts at 2000h. 86Box maps file offset 2000h to C0000h (`rom_init(..., 0xc0000, 0x8000, 0x7fff, 0x2000, ...)`, vid_vga.c line 244) |
| Same bytes rotated by 8 KB (ROM first, then 8 KB of 00) | CRC32 `74e3fadb`, SHA-1 `dce6491424f1726203776dfae9a967a98a4ba7b5`: **equal to MAME's `ibm-vga.bin` entry** (flagged `BAD_DUMP` there), which MAME maps at C0000h-C7FFFh |
| Option ROM | `55 AA 30` (48 x 512 = 24 KB), 8-bit sum over 24 KB = 00h, `JMP 003Bh` at 0003h |
| VIDEO_PARMS | 29 entries x 64 bytes at CPU offset 1342h (layout below) |
| Fonts | 8x8 at 378Dh (INT 43h vector), 8x14 at 3F8Dh, 9x14 patches at 4D8Dh, 8x16 at 4EBAh, 9x16 patches at 5EBAh |

What could not be cross-checked: no IBM document prints this ROM or its
part number; the only two independent dumps (86Box, MAME) are the same bytes
in two arrangements and MAME marks its own dump BAD_DUMP. That the 24 KB is
the ROM of the *PS/2 Display Adapter* (rather than another IBM ISA VGA) rests
on 86Box/MAME naming and on the ROM itself programming the adapter's setup
port 46E8h and POS register 102h, which a planar VGA does not have.

## The board modeled

IBM Personal System/2 Display Adapter: an 8-bit ISA card with the VGA
function (HITR Type 1: CRT controller, sequencer, graphics controller,
attribute controller in one gate array), 256 KB of video memory as four 64 KB
maps, a 256 x 18-bit video DAC (Inmos IMS G171 compatible), the 25.175 MHz
and 28.322 MHz oscillators, the BIOS ROM, the setup/enable port 46E8h with
POS register 102h, and the 15-pin analog display connector.

**Introduced: 1987.** IBM announcement letter ENUS187-054, "The IBM Personal
System/2 Display Adapter, the IBM Personal System/2 Display Adapter 8514/A
and the IBM Personal System/2 8514 Memory Expansion Kit", is dated
2 April 1987 (the PS/2 announcement day; cited through Wikipedia "Video
Graphics Array", the IBM page itself did not render offline). The ROM is
dated 10/27/86. PC Magazine (W. Rosch, 22 December 1987, p.35) reviewed the
card as "IBM VGA Adapter Card: 256K Video RAM, 17 Display Modes". The month
the card first shipped is not established.

Not modeled: the VGA auxiliary/feature connector (ESYNC/EVIDEO/EDCLK, P7-P0;
the external clock input is a tie-off `ext_osc_ce_i`), the monitor ID pins
(the adapter BIOS never reads them, see the I/O audit), DRAM refresh and
CPU/CRT memory interleaving (no wait states, V24), the 3-PEL-clock analog
pipeline of the DAC and all analog and AC timing (V23).

## Architecture

One clock domain `clk`; every input is sampled on `clk`; the oscillators
are clock-enable inputs. Synchronous active-low `rst_n` is the
simulation/FPGA power-on reset (V1). The slot's RESET DRV is a separate input
(V2). One module per file:

| File | Function | Contents |
|---|---|---|
| `ibm_vga.sv` | card | slot and monitor ports, sampling, data-bus mux, wiring |
| `vga_io_decode.sv` | card decode | I/O and memory decode, 46E8h/102h gating |
| `vga_general_regs.sv` | general registers + card registers | Misc Output, Feature Control, Input Status 0/1 fields, 46E8h, POS 102h, clock source mux |
| `vga_sequencer.sv` | sequencer | 5 registers, dot/character clocks, CPU plane address (odd/even, chain 4), map-mask enables, character map select |
| `vga_crtc.sv` | CRT controller | 25 registers, protect bit, 10-bit vertical, double scan, word/doubleword addressing, counters, interrupt |
| `vga_graphics_ctrl.sv` | graphics controller | 9 registers, latches, write modes 0-3, read modes 0/1, serializer (CGA shift, 256-colour) |
| `vga_display_fetch.sv` | display pipeline | plane fetch, character generator fetch, character pipeline |
| `vga_attribute_ctrl.sv` | attribute controller | 21 registers + flip-flop, panning (with line-compare reset), blink, cursor, 8-bit DAC address |
| `vga_dac.sv` | video DAC | 256 x 18 palette, PEL mask, address/read/write state machine, DAC state, RGB outputs, switch-sense comparator |
| `vga_plane_ram.sv` | video memory | one 64 KB map: CPU port, display port, debug port |
| `vga_rom.sv` | BIOS ROM | 32 KB window, `$readmemh(ROM_FILE)` |

## Interface (`ibm_vga`)

| Parameter | Default | Meaning |
|---|---|---|
| `ROM_FILE` | `""` | `$readmemh` image of the 32 KB ROM window in CPU order (`work/firmware/vga_rom.hex` from `get_rom.py`). Empty: ROM reads 00h |

| Port | Dir | Meaning |
|---|---|---|
| `clk` | in | Design clock. **Minimum rate: the fastest oscillator the host drives (28.322 MHz with `osc28_ce_i`, i.e. clk / dot clock >= 1.0)**: each oscillator enable may be high in at most one clock per period. Any faster clk and any enable pattern work (no fixed ratio; enables from phase accumulators are fine); see "Clocking requirement" |
| `rst_n` | in | Synchronous power-on reset of all card state (simulation/FPGA), not a slot pin |
| `reset_drv_i` | in | Slot B2 RESET DRV, active high (V2) |
| `a_i[19:0]` | in | Slot A19-A0 |
| `d_i[7:0]` | in | Slot D7-D0 into the card |
| `d_o[7:0]`, `d_oe_o` | out | Data the card drives and its enable (I/O read of a readable port, memory read of the ROM or the enabled RAM window) |
| `ior_n_i`, `iow_n_i`, `memr_n_i`, `memw_n_i` | in | -IOR, -IOW, -MEMR, -MEMW |
| `aen_i` | in | AEN; high disables the I/O decode |
| `dack0_n_i` | in | Slot B19 (-DACK0 on the PC/XT, -REFRESH on the AT). Low disables the memory decode (kept from the EGA, V3) |
| `irq2_o`, `irq2_oe_o` | out | Slot B4 "IRQ 2" (IRQ 9 on the AT): vertical-interrupt latch and its driver enable (VRE bit 5 = 0) |
| `iochrdy_o`, `iochrdy_oe_o` | out | Slot A10 I/O CH RDY; never driven (`iochrdy_oe_o` = 0, V24) |
| `osc25_ce_i` | in | One pulse per period of the 25.175 MHz oscillator |
| `osc28_ce_i` | in | One pulse per period of the 28.322 MHz oscillator |
| `ext_osc_ce_i` | in | External clock of the auxiliary video connector (tie to 0) |
| `load_i[2:0]` | in | Monitor load on the red/green/blue outputs: bit = 1 when that output is terminated by the display (75 ohm). Colour display 3'b111, monochrome display 3'b010 (only pin 2, "Mono", HITR Figure 98), no display 3'b000. Drives the switch-sense comparator (V21) |
| `pix_en_o` | out | One pulse per dot clock; the outputs below hold that dot while it is high |
| `r_o[5:0]`, `g_o[5:0]`, `b_o[5:0]` | out | The DAC's 6-bit red, green, blue values for the dot (0 while blanked) |
| `hsync_o`, `vsync_o` | out | Display connector pins 13/14: retrace XOR Misc Output bits 6/7 |
| `blank_o`, `de_o` | out | Composite blank (the DAC blank input) and display enable of the dot (simulation aids) |
| `dbg_reg_addr_i[7:0]`, `dbg_reg_data_o[7:0]` | in/out | Simulation-only, side-effect-free register read (map below) |
| `dbg_plane_i[1:0]`, `dbg_mem_addr_i[15:0]`, `dbg_mem_data_o[7:0]` | in/out | Simulation-only plane memory read |
| `dbg_dac_i[7:0]`, `dbg_dac_o[17:0]` | in/out | Simulation-only DAC entry read `{R,G,B}` |

### Clocking requirement

The oscillators are clock enables (`osc25_ce_i`, `osc28_ce_i`,
`ext_osc_ce_i`): a pulse is one period of that oscillator. The card makes at
most one dot per `clk`, so `clk` must be at least as fast as the fastest
oscillator the host enables: **clk >= 28.322 MHz** when `osc28_ce_i` is
driven (the 9-dot text modes 0+ to 3+, 7, 7+ select it), clk >= 25.175 MHz
if only `osc25_ce_i` is driven. A host clocked more slowly (the AT machine
top's clk stands for 24 MHz) must run the card from a faster clk (for
example twice its own) or it cannot produce the documented dot rates. Above
the minimum the card makes no assumption about the ratio or the regularity
of the enables: the display fetch needs 3 clocks per character and a
character is at least 8 dots, so 8 clocks. `run_sim.sh` reruns the directed
tests, two random seeds, four BIOS mode-table entries and the Unicorn mode
13h run with clk at 29.0 MHz and 47.3 MHz and the enables generated by
phase accumulators (`VGA_CLK_MHZ` in `tb/vga_tb.cpp`); every trace equals
the model's.

### Bus timing (identical to `ibm_ega`)

All slot inputs are sampled every `clk`. A write (I/O or memory) takes
effect at the rising edge of -IOW/-MEMW, with the address and data sampled
in the last clock the strobe was low. A read drives `d_o`/`d_oe_o` while the
strobe is low (valid from the second clock of the strobe); its side effects
(attribute flip-flop reset, processor latch load, DAC read advance) happen
at the rising edge. A 16-bit processor access reaches this 8-bit card as two
byte cycles (low byte at the even address first), as the AT bus does for an
8-bit slot; the card never asserts -MEMCS16/-IOCS16 (not slot pins of this
model). `tb/vga_tb.cpp` drives: address/AEN stable, strobe low 3 clocks,
strobe high, 2 idle clocks.

### Frame-capture contract (identical to `ibm_ega` with RGB)

A host rebuilds the picture by sampling, on every `clk` where `pix_en_o` is
1: `r_o`, `g_o`, `b_o`, `hsync_o`, `vsync_o` (optionally `blank_o`,
`de_o`). Each such sample is one dot. A line starts at the dot after a
falling edge of the retrace signal (polarity removed). The dot rate is the
selected oscillator, divided by 2 when Clocking Mode bit 3 is 1.

### Debug register map (`dbg_reg_addr_i`)

| Addr | Contents | Addr | Contents |
|---|---|---|---|
| 00-04 | sequencer 0-4 | 05 | sequencer index |
| 10-28 | CRTC 00-18h | 29 | CRTC index |
| 30-38 | graphics 0-8 | 39 | graphics index |
| 40-4F | palette 0-F | 50-54 | attribute 10-14h |
| 55 | attribute address (bit 5 = IPAS) | 56 | attribute flip-flop |
| 60 | Misc Output | 61 | Feature Control |
| 62-65 | latches 0-3 | 67 | vertical-interrupt latch |
| 68 | blink counter | 69 | 46E8h register |
| 6A | POS 102h | 70 | PEL mask |
| 71 | DAC address | 72 | DAC sub-index (0-2) |
| 73 | DAC mode (1 = read) | 74-75 | DAC write holding R, G |
| 76 | switch sense (bit 0) | other | FFh |

## I/O and memory decode

I/O ports are decoded on A9-A0 (A15-A10 not decoded, V3) when AEN is low,
**and only while the card is enabled**: 46E8h bit 3 = 1 and POS 102h bit 0 =
1 (HITR p.10 and the ROM sequence C000:0096-00AA, V4). `x` = B when Misc
Output bit 0 = 0, D when 1.

| Port | Write | Read | Basis |
|---|---|---|---|
| 3C0 | attribute address / data (flip-flop) | attribute address | p.2-89, HITR p.76 |
| 3C1 | not decoded | attribute data at the current index | p.2-89 (V6) |
| 3C2 | Misc Output | Input Status 0 | p.2-42 |
| 3C3 | not decoded (V5) | not decoded | V5 |
| 3C4 / 3C5 | sequencer address / data | readback | p.2-47 |
| 3C6 | PEL mask | PEL mask | HITR p.37 R/W |
| 3C7 | DAC read address | DAC state | p.2-105 |
| 3C8 | DAC write address | DAC address | p.2-105 (V20) |
| 3C9 | DAC data | DAC data | p.2-105 |
| 3CA | not decoded | Feature Control | p.2-46 |
| 3CC | not decoded | Misc Output | p.2-42 |
| 3CE / 3CF | graphics address / data | readback | p.2-78 |
| 3x4 / 3x5 | CRTC address / data | readback | p.2-55 |
| 3xA | Feature Control | Input Status 1, resets the attribute flip-flop | p.2-45 |

The DAC ports 3C6-3C9 are not decoded while 46E8h bit 4 (setup) is 1 (HITR
p.10, V4). Card-level ports, decoded on A15-A0 exactly and independent of
the enable:

| Port | Write | Read | Basis |
|---|---|---|---|
| 46E8 | bit 3 video enable, bit 4 setup; bits 2-0, 7-5 stored, no function | not decoded | ROM C000:0096-00AA, INT 10h AH=12h BL=32h (C000:096B-097D) writes 0Eh = enable, 00h = disable (V4) |
| 102 | POS register 2, bit 0 video enable (only while 46E8h bit 4 = 1) | POS 102h (setup only) | HITR p.10 "only POS Register 2 (hex 0102) is used" (V4) |

Memory: the ROM at C0000h-C7FFFh (32 KB window; bytes 6000h-7FFFh read 00h,
V22) for reads, independent of the enable; the RAM, when the card is
enabled and Misc Output bit 1 = 1, in the window of Graphics Miscellaneous
bits 3-2: 00 = A0000h-BFFFFh, 01 = A0000h-AFFFFh, 10 = B0000h-B7FFFh, 11 =
B8000h-BFFFFh (p.2-86). -DACK0/-REFRESH low disables both.

## Registers

Readback returns the stored bits; bits IBM marks "Set to 0, Undefined on
Read" are not stored and read 0 (V7). Stored widths: sequencer address 3
bits, Reset 2, Clocking Mode 6 (bit 1 not stored: "set to 1"), Map Mask 4,
Character Map Select 6, Memory Mode 3 (bits 3-1); CRTC address 5 bits, every
CRTC register 8 bits except Preset Row Scan (7), Cursor Start (6), Cursor
End (7), Underline (7), Mode Control (bit 4 not stored); graphics address 4,
Set/Reset 4, Enable 4, Compare 4, Rotate 5, Read Map 2, Mode 7 (bit 2 not
stored), Misc 4, Don't Care 4, Bit Mask 8; attribute address 6, palette 6,
Mode Control 8 (bit 4 not stored), Overscan 8, Plane Enable 6 (bits 5-4 select
the video status mux, V16), Panning
4, Color Select 4; Misc Output 8 (bits 5-4 stored: bit 5 is the odd/even page
bit V13), Feature Control 8 (stored, no function: "All bits are reserved").

| Group | Index | Register | Fields used (VGAXGA page) |
|---|---|---|---|
| General | - | Misc Output (W 3C2, R 3CC) | 0 I/O select, 1 enable RAM, 3-2 clock (00 25.175, 01 28.322, 10 external, 11 none), 5 odd/even page (V13), 6 HSP, 7 VSP (p.2-42) |
| | - | Input Status 0 (3C2) | 7 CRT interrupt pending, 4 switch sense (V21); others 0 |
| | - | Input Status 1 (3xA) | 5-4 video status mux (V16), 3 vertical retrace, 0 = 1 while display enable is off (p.2-45); others 0 |
| Sequencer | 00 | Reset | 1-0 both 1 to run (p.2-48) |
| | 01 | Clocking Mode | 0 8/9 dots, 2 shift load, 3 dot clock /2, 4 shift 4, 5 screen off (p.2-49) |
| | 02 | Map Mask | 3-0 |
| | 03 | Character Map Select | A = {5,3,2}, B = {4,1,0}; map n at plane 2 offset per Figure 2-34 |
| | 04 | Memory Mode | 1 extended memory, 2 odd/even (0 = odd/even), 3 chain 4 (p.2-54) |
| CRTC | 00 | Horizontal Total | characters - 5 (p.2-56) |
| | 01 | Horizontal Display End | displayed characters - 1 |
| | 02/03 | Start/End Horizontal Blank | end = 6 bits {05.7, 03.4-0}; 03.6-5 display enable skew |
| | 04/05 | Start/End Horizontal Retrace | end 5 bits; 05.6-5 retrace delay |
| | 06/07 | Vertical Total, Overflow | 10-bit VT ({07.5, 07.0, 06}); lines per frame = VT + 2 (p.2-61); VDE {07.6,07.1,12}, VRS {07.7,07.2,10}, VBS {09.5,07.3,15}, LC {09.6,07.4,18} |
| | 08 | Preset Row Scan | 4-0 starting row scan, 6-5 byte panning (V11) |
| | 09 | Maximum Scan Line | 4-0 MSL, 7 double scan (p.2-64) |
| | 0A/0B | Cursor Start/End | 0A.5 cursor off; 0B.6-5 cursor skew |
| | 0C-0F | Start Address, Cursor Location | 16 bits each |
| | 10/11 | Vertical Retrace Start/End | 11.3-0 end, 4 clear interrupt (0 = clear), 5 enable (0 = enable), 6 five refresh cycles (stored, no function), 7 protect 0-7 (p.2-69) |
| | 12 | Vertical Display End | 10 bits; displayed lines = VDE + 1 |
| | 13 | Offset | row step = 2 x Offset address units |
| | 14 | Underline Location | 4-0, 5 count by 4, 6 doubleword (p.2-72) |
| | 15/16 | Start/End Vertical Blank | start 10 bits, end 8 bits (V10) |
| | 17 | Mode Control | 0 CMS0, 1 SRC, 2 HRS, 3 count by two, 5 address wrap, 6 word/byte, 7 retrace enable (p.2-74) |
| | 18 | Line Compare | 10 bits |
| Graphics | 00-02 | Set/Reset, Enable Set/Reset, Color Compare | 3-0 |
| | 03 | Data Rotate | 2-0 count (rotate right, p.2-82), 4-3 function |
| | 04 | Read Map Select | 1-0 |
| | 05 | Graphics Mode | 1-0 write mode, 3 read mode, 4 odd/even, 5 shift register, 6 256-colour (p.2-84) |
| | 06 | Miscellaneous | 0 graphics, 1 odd/even (chain), 3-2 memory map |
| | 07 | Color Don't Care | 1 = map takes part in the compare (p.2-87) |
| | 08 | Bit Mask | |
| Attribute | 00-0F | Palette | 5-0 |
| | 10 | Mode Control | 0 graphics, 1 mono emulation, 2 line graphics, 3 blink, 5 panning compatibility, 6 PEL width, 7 P5/P4 select (p.2-92) |
| | 11 | Overscan | 7-0 (8-bit DAC address) |
| | 12 | Color Plane Enable | 3-0 |
| | 13 | Horizontal PEL Panning | 3-0 (Figure 2-88) |
| | 14 | Color Select | 3-2 P7-P6, 1-0 P5-P4 when 10h bit 7 = 1 (p.2-96) |
| DAC | 3C6 | PEL Mask | ANDed with the DAC address (V19) |
| | 3C7/3C8/3C9 | address, data | 18-bit entries, R then G then B, address increments after B (p.2-104/105) |

The CRTC Protect bit (11h bit 7) blocks writes to indices 00-07 except
Overflow bit 4 (LC8), which is still written (p.2-70).

## Behavior

### Clocks

A **master pulse** is a `clk` with the selected oscillator enable high
(Misc Output bits 3-2: 00 `osc25_ce_i`, 01 `osc28_ce_i`, 10 `ext_osc_ce_i`,
11 none). The sequencer runs when Reset bits 1-0 are 11; halted: no dots,
CRTC frozen, phase cleared (EGA E6, V8). Running: every master pulse is a
dot, or every second one (the first) when Clocking Mode bit 3 = 1 (EGA E7).
A character is 9 dots when Clocking Mode bit 0 is 0, else 8.

### CRTC timing

As the EGA (spec "CRTC timing", E12-E16) with the VGA widths: `hc` runs 0 ..
HT+4 (HT+5 characters, p.2-56); `vc` 0 .. VT+1 (10 bits). Display enable:
`hc <= HDE` and `vc <= VDE`. Horizontal blank on at `hc == SHB`, off at the
first later character with `hc[5:0] == EHB` (6 bits); retrace on at `hc ==
SHR`, off at `hc[4:0] == EHR`. Vertical blank on at `vc == VBS` (10 bits), off
at the first later line with `vc[7:0] == EVB` (V10); retrace on at `vc ==
VRS`, off at `vc[3:0] == VRE`. The line advances where horizontal retrace
starts (EGA E13), every second time with Mode Control bit 2.

At a line advance: at `vc == VT+1` the frame restarts (`vc` = 0, row scan =
Preset Row Scan, row start = Start Address + byte panning (V11), double-scan
phase = 0). Otherwise `vc` increments; the **row-scan clock** then ticks
every line, or every second line when Maximum Scan Line bit 7 = 1 (double
scan, p.2-64, V9). At a row-scan tick the row scan wraps to 0 after MSL
(adding 2 x Offset to the row start) or increments. When the line being left
equals Line Compare the row start becomes 0 (screen B, p.2-103), and the
double-scan phase restarts (V9).

The memory address counter `ma` = row start at `hc = 0`, then +1 per
character, per 2 characters with Mode Control bit 3 (count by two) or per 4
with Underline bit 5 (count by 4). Output multiplexer (Figure 2-65):
doubleword (14h bit 6 = 1) `{ma[13:0], ma[13:12]}`; else word (17h bit 6 =
0) `{ma[14:0], ma[15] or ma[13]}` by 17h bit 5; else byte `ma`; then bit 13
= `rs[0]` when 17h bit 0 = 0 and bit 14 = `rs[1]` when 17h bit 1 = 0. Cursor:
`ma == cursor location`, `CS <= rs < CE` (EGA E16) and Cursor Start bit 5 =
0. Underline row `rs == UL`. Mode Control bit 7 = 0 forces both retraces
inactive.

The vertical interrupt latch is set when vertical retrace starts if VRE bit
5 = 0 and bit 4 = 1, and is held clear while bit 4 = 0 (p.2-70; EGA E9: IRQ 2
high while set, Input Status 0 bit 7 = latch).

### Display pipeline

At each character boundary the four map bytes are read at the display
address. With Graphics Miscellaneous bit 0 = 0 (alphanumeric) the map 2 byte
is read at the character generator address `{map, char, rs}` where `map`
selects an 8 KB table of map 2 per Figure 2-34 (map n at offset
`{n[1:0], n[2]} x 8 KB`), the char is the map 0 byte and `rs` 5 bits (V12).
Map A is used when attribute bit 3 = 1, extended memory is 1 and A != B,
else map B (EGA E17 with 3-bit maps); without extended memory map 0.

Pixel indices (EGA "Display pipeline", E19-E24) then:
- 256-colour serializer (Graphics Mode bit 6): dot `2i` = map `i` bits 7-4,
  dot `2i+1` = map `i` bits 3-0, `i` = 0..3 (V17); else CGA shift (bit 5) or
  planar, as the EGA.
- Attribute Mode bit 6 (PEL width): dots are taken in pairs (0,1), (2,3) ..
  of the panned stream; each index of the pair passes Color Plane Enable and
  the palette; the DAC address is `{pal(first)[3:0], pal(second)[3:0]}` for
  both dots (V18). Otherwise the DAC address is `{CS[3:2], P5P4, pal[3:0]}`
  with P5P4 = palette bits 5-4 or Color Select bits 1-0 when Attribute Mode
  bit 7 = 1 (p.2-92, p.2-96).
- Overscan (border, 8 bits) when display enable is off or IPAS = 0 (EGA
  E27); blank forces the DAC output to 0 (p.2-104).
- Panning (Figure 2-88): 9-dot characters 8,0,1..7 (EGA E24); 8-dot
  characters `pan[2:0]` dots; it is forced to 0 from a line-compare match to
  the next vertical retrace when Attribute Mode bit 5 = 1 (p.2-92).
- Clocking Mode bit 5 (screen off) blanks the dots; syncs continue (p.2-49).
- Blink counter as EGA E23, cursor as E23 but suppressed by Cursor Start bit 5.

Pipeline depths, in characters from the CRTC counter state to the output
(V14): graphics (Graphics Misc bit 0 = 1): data 2, display enable 2 + skew,
blank 3, cursor 2 + cursor skew; alphanumeric: data 3, display enable 3 +
skew, blank 4, cursor 3 + cursor skew; horizontal retrace = its delay field;
vertical retrace 0.

### Video DAC (p.2-104 to 2-106)

The 8-bit DAC address of the dot is ANDed with the PEL mask (V19) and selects
an 18-bit entry; the outputs are its R, G, B (6 bits each), 0 while blanked.
Address register `A`, sub-index `s` (0..2), mode: write 3C8 = `A <= v, s <= 0,
mode write`; write 3C7 = `A <= v, s <= 0, mode read`; write 3C9 stores byte `s`
(6 bits); at `s = 2` the entry `A` is written with the three bytes and `A`
increments; read 3C9 returns component `s` of entry `A` and at `s = 2` `A`
increments; read 3C8 returns `A`; read 3C7 returns `mode ? 03h : 00h`. The
sub-index is shared by reads and writes (V20).

### Switch sense (Input Status 0 bit 4)

The comparator looks at the analog outputs of the current dot: an output
with load (`load_i` bit = 1) is at `v x 0.7 V / 63`, an open output at twice
that. The sense bit is 1 when every output is below the reference (V21).

### Processor memory access

Offset `o` into the RAM window. Plane address: chain 4 (Memory Mode bit 3):
`{o[15:2], o[15:14]}` (V15), the map is `o[1:0]`; odd/even chain (Graphics
Misc bit 1): `{o[15:1], X}` with X = `o[16]` (128 KB map) or NOT Misc Output
bit 5 (EGA E28, V13); else `o[15:0]`. Bits 15-14 are 0 unless Memory Mode bit
1 is 1. A write goes to the maps enabled by Map Mask, restricted to `1 <<
o[1:0]` in chain 4 or to maps 0/2 (even) / 1/3 (odd) when Memory Mode bit 2 =
0. A read loads all four latches. Read mode 0 returns map `o[1:0]` (chain
4), `{rms[1], o[0]}` (Graphics Mode bit 4), else Read Map Select; read mode 1
returns 1 where every map with Don't Care = 1 equals its Color Compare bit.

| Write mode | Data before the function | Bit mask |
|---|---|---|
| 0 | rotated CPU byte, or 8 x Set/Reset bit where Enable Set/Reset = 1 | Bit Mask |
| 1 | latches written unchanged | - |
| 2 | 8 x CPU data bit `n` | Bit Mask |
| 3 | 8 x Set/Reset bit `n` (enable ignored) | Bit Mask AND rotated CPU byte (p.2-85) |

Modes 0, 2, 3: function (none/AND/OR/XOR with the latch), then `(f & mask) |
(latch & ~mask)`.

## Assumptions

| Tag | Assumption | Basis | Checked by |
|---|---|---|---|
| V1 | `rst_n` clears every register, latch, counter, DAC entry and flip-flop to 0 | Power-on state not documented | `power_on` |
| V2 | RESET DRV (synchronously sampled) clears Misc Output, 46E8h and POS 102h (card disabled until the BIOS enables it) and holds the CRTC counters and interrupt latch at 0 (EGA E2); other registers keep their values | Not documented for the VGA. The option ROM must be readable before the BIOS enables the card (the system BIOS scans C0000h first), which is why the ROM decode is not gated (V4) | `reset_drv` |
| V3 | The 3B0-3DF ports are decoded on A9-A0 (alias every 400h, as the EGA's U16); -DACK0/-REFRESH low disables the memory decode | No schematic of the adapter; reuses EGA sheet 4. 46E8h/102h are decoded on all 16 bits (46E8h's low 10 bits are 2E8h, COM4) | `io_decode_aliases`, mutant m12 |
| V4 | Card enable = 46E8h bit 3 AND POS 102h bit 0; it gates every 3xx port and the RAM, not the ROM, 46E8h or 102h. 46E8h bit 4 = setup: POS 102h accessible, DAC ports not decoded. RESET DRV disables | HITR p.10 (planar: setup through 94h bit 5, POS 102h bit 0 enable, DAC disabled in setup, "If video output is being generated ... the output is still generated"); the ROM writes 46E8h = 16h, 102h = 01h, 46E8h = 0Eh (C000:0096-00AA) and AH=12h BL=32h writes 0Eh/00h (C000:096B-097D). 86Box also ANDs 46E8h bit 3 with 102h bit 0 | `card_enable`, Unicorn POST, formal (card top) |
| V5 | Port 3C3 (planar "Video Subsystem Enable", HITR p.41) is not decoded on the adapter | The ROM never accesses 3C3 (static audit and Unicorn trace); the adapter uses 46E8h instead | I/O audit |
| V6 | 3C1 writes are not decoded (reads return the attribute data register); palette reads with IPAS = 1 return the register | p.2-89: 3C0 write, 3C1 read; "reads return undefined data". The BIOS never writes 3C1 (static audit; every attribute write is OUT 3C0) | `attribute_readback`, I/O audit |
| V7 | Bits marked "Set to 0, Undefined on Read" and reserved bits read 0 and are not stored; reserved CRTC indices 19h-1Fh read 00h and ignore writes | Undefined in the documents | `registers_readback` |
| V8 | Sequencer halted: no dots, CRTC frozen, dot phase 0 (EGA E6); asynchronous reset does not clear Character Map Select | EGA TR p.19/23 for the EGA; VGAXGA p.2-48 says only "clear and halt" | `sequencer_reset` |
| V9 | Double scan divides the row-scan clock (row scan and row address) by 2 with a phase that restarts at the frame start and at a line-compare match | p.2-64 "the clock in the row scan counter is divided by 2"; p.2-99 requires an even Line Compare in 200-line modes, consistent with the phase restart | `double_scan`, BIOS modes 0-6, D, E |
| V10 | Vertical blank: on at `vc == VBS` (10 bits), off at `vc[7:0] == EVB`; horizontal blank end 6 bits; the "minus 1" phrases of p.2-73 are not applied | With the BIOS mode 12h values this gives exactly HITR Figure 102: blank 29 lines, front porch 3, sync 2, back porch 24 (0.922/0.095/0.064/0.763 ms) | BIOS geometry |
| V11 | Byte panning (Preset Row Scan 6-5) is added to the start address at the frame start | p.2-63 "controls byte panning in multiple shift modes"; the BIOS writes 0 | random |
| V12 | Character generator address `{map_off, char, rs[4:0]}`: 8 KB tables, 32 bytes per character | Figure 2-34, Figure 2-90 (up to 32 scan lines) | `char_map_select` |
| V13 | Misc Output bit 5 is stored and is the odd/even page bit of the EGA (A0 replaced by NOT bit 5 outside the 128 KB map) | HITR marks bits 5-4 reserved, but the BIOS writes bit 5 = 1 in every mode (63h, A6h, E3h ...) exactly as the EGA BIOS; EGA E28 | BIOS text replay |
| V14 | Pipeline depths: graphics data 2 / DE 2+skew / blank 3; alphanumeric data 3 / DE 3+skew / blank 4; horizontal retrace = delay field; vertical retrace 0 | Not documented. Chosen so that the BIOS values of mode 12h and mode 3+ produce HITR Figure 103 (80 column with border: blanking 5.720, front porch 0.318, sync 3.813, back porch 1.589 us); the other 21 entries are then a check, not an input | BIOS geometry |
| V15 | Chain 4 CPU plane address `{o[15:2], o[15:14]}` | Not documented; the doubleword CRTC output `{MA13-0, MA13-12}` (Figure 2-65) fetches plane address `{o[15:2], o[15:14]}` for CPU byte `o` of mode 13h; only this makes the whole 64,000-byte mode 13h buffer display | `chain4`, BIOS mode 13h replay |
| V16 | Input Status 1 bits 5-4 are the EGA's video status multiplexer (EGA E11), selected by Color Plane Enable bits 5-4: 00 {P2,P0}, 01 {P3,P1}, 10 {P5,P4}, 11 none; the tap is the attribute controller's DAC address of the last dot, 0 in horizontal/vertical blanking but not forced by Screen Off | HITR calls bits 7-4 reserved and Color Plane Enable 7-4 "set to 0". The POST (C000:0270-029B) writes Color Plane Enable 0Fh, 1Fh, 2Fh with palette 15 = 3Fh and a row of index-15 pixels, and fails (beep 1 long 3 short) unless bits 5-4 become nonzero and zero again for each; it runs with Clocking Mode 29h (Screen Off). Setting 11 is never used by the ROM | Unicorn POST, `status_bits`, coverage `diag_nonzero_0..2` |
| V17 | 256-colour serializer: dot 2i = map i high nibble, dot 2i+1 = low nibble | p.2-22 "four bit planes are sampled twice to produce eight bit-plane values", p.2-84 | `mode13_pixels`, BIOS 13h replay |
| V18 | PEL width: the pair (first dot high nibble) is formed after panning and plane enable; each nibble passes the palette; DAC address = `{pal(first)[3:0], pal(second)[3:0]}` | p.2-92/2-97 say only that the 8-bit attribute becomes the DAC address; the BIOS palette is the identity in mode 13h | `mode13_pixels` |
| V19 | The DAC address is ANDed with the PEL mask | Not described (p.2-106: "do not write"). The POST writes PEL mask 00h before the sense test (C000:0381) so that every dot uses entry 0, which it then programs (C000:046C) | `dac_pel_mask`, Unicorn POST |
| V20 | DAC: one address register and one shared sub-index; 3C8 read = address; a data access in the other direction uses the same counter | p.2-105 leaves cross-direction accesses "undefined and can change the palette contents" | `dac_state_machine`, formal (DAC) |
| V21 | Switch sense = 1 when every R/G/B output is below the reference; reference between DAC code 20 and 32 with load (26 used: 0.289 V), an open output doubles the voltage | Not documented ("test circuitry", p.2-5). Bounded by the POST tables at C000:0428/043C/0450/0454/0458: colour (12,12,12) and (14,14,14) must read 1 and (2D,14,14) 0; mono (04,12,04) 1, (1E,12,04) and (04,16,15) 0; none (04,04,04) 1, (10,04,04) 0. 86Box uses a per-channel threshold 26h on DAC entry 0 for colour only | `switch_sense`, Unicorn POST for colour, mono and no display |
| V22 | The ROM window is 32 KB at C0000h-C7FFFh with the image in the first 24 KB and 00h above | MAME's dump/map (32 KB, ROM first); the 86Box file has the 8 KB of zeros first but maps file 2000h at C0000h, so both put 55 AA at C0000h | `rom_read` |
| V23 | The DAC output is shown with the dot that produced it (the 3-clock DAC pipeline is not modeled) | HITR Figure 96 T8 "3(T1) + 5 ns" | - |
| V24 | No wait states (EGA E26); refresh-count, Shift 4, Five Refresh and Feature Control bits stored only | No arbitration documented | - |
| V25 | Cursor and underline rows as EGA E16 (CS <= rs < CE, UL on rs == UL, 1-based "minus 1" phrases) | p.2-65/66/72 use the same phrasing as the EGA TR; the BIOS cursor 0D/0E in 16-line modes gives a 1-row cursor at row 0Dh | BIOS replay mode 3 |

## BIOS usage

`VIDEO_PARMS` (C000:1342h) has 29 entries of 64 bytes: columns, rows,
points, page length (word), sequencer 1-4, Misc Output, CRTC 00-18h,
attribute 00-13h, graphics 0-8. Entries: 0-7 = modes 0-7 (0-3 200-line,
double scanned), 8 = mode 8 slot, 9 = empty, 0Ah-0Ch = reserved/font-load
sets, 0Dh-10h = modes D-10h (64 KB), 11h/12h = modes F/10h (more than
64 KB), 13h-16h = modes 0*-3* (350 lines), 17h/18h = 0+/1+ and 2+/3+ (400
lines, 9x16), 19h = 7+, 1Ah-1Ch = modes 11h-13h (`scripts/vga_bios.py`).

## Differences from the EGA slot interface

| `ibm_ega` port | `ibm_vga` | Why |
|---|---|---|
| `osc14_ce_i`, `osc16_ce_i` | `osc25_ce_i`, `osc28_ce_i` | VGA clocks (p.2-43); the VGA does not use the slot OSC |
| `sw_i[3:0]`, `p1_i`, `p3_i` | removed | no switches or jumpers; display type from `load_i` |
| `feat_i`, `fc_o` | removed | feature connector not modeled; Feature Control bits reserved |
| `lpen_n_i`, `lpen_sw_n_i` | removed | the VGA has no light pen (CRTC 10h/11h are retrace registers) |
| `video_o[5:0]`, `video_oe_o` | `r_o`, `g_o`, `b_o` [5:0] | analog DAC instead of TTL direct drive |
| - | `load_i[2:0]` | monitor load for the switch sense |
| - | `dbg_dac_i`, `dbg_dac_o` | DAC debug read |
| everything else | identical | `clk`, `rst_n`, `reset_drv_i`, `a_i`, `d_i`, `d_o`, `d_oe_o`, strobes, `aen_i`, `dack0_n_i`, `irq2_o/oe`, `iochrdy_o/oe`, `ext_osc_ce_i`, `pix_en_o`, `hsync_o`, `vsync_o`, `blank_o`, `de_o`, `dbg_*` and the bus timing |

## Disagreements between documents, emulators and the ROM

| Item | Documents | ROM | MAME / 86Box | This model |
|---|---|---|---|---|
| Video enable port | HITR: 3C3 bit 0 (planar) and POS via 94h/102h | 46E8h + 102h, never 3C3 | 86Box ISA VGA: 46E8h bit 3 AND 102h bit 0; MAME: none | ROM (V4, V5) |
| PEL mask access | HITR p.37 R/W; VGAXGA p.2-104 "R" and "do not write" | writes 00h and FFh | R/W | R/W |
| Switch sense | "test circuitry" only | five-value tables per display type | 86Box: entry-0 threshold 26h, colour only | load-dependent comparator (V21) |
| ROM image | - | 24 KB at C0000h | MAME 32 KB, ROM first, BAD_DUMP; 86Box zeros first, offset 2000h | V22 |
| Chain 4 low address bits | not stated | mode 13h uses doubleword | 86Box: plane address `o & FFFCh` with its own display mapping | V15 |
| 3C1 writes | read-only port (p.2-89) | never written | 86Box accepts 3C1 writes | not decoded (V6) |

## Not modeled

Feature/auxiliary video connector, monitor ID pins, wait states and memory
arbitration, DRAM refresh, Shift 4 multiple-shift modes beyond storing the
bit, five-refresh-cycle selection, the DAC pipeline and analog/AC timing,
interlace (none), and the 8514/A port 4AE8h the ROM writes (another card).
