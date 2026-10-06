# Apple IIe MMU (341-0266) specification

## Sources and scope

The [Apple IIe Technical Reference Manual, 2nd edition, © Apple Computer 1985](https://archive.org/details/Apple_IIe_Technical_Reference_Manual) is the primary reference: Chapter 4 defines the bank-select switches (Table 4-6), the auxiliary-memory select switches (Table 4-7) and the reset state; Chapter 6 defines SLOTC3ROM/SLOTCXROM (Table 6-5); Chapter 7 defines the MMU pinouts and signal descriptions (Figure 7-2, Table 7-6) and the RAM address multiplexing (Table 7-9). The Monitor ROM listing in the manual's Appendix I supplies the soft-switch equate block and the auxiliary-memory subroutines used as historical stimulus.

Three independent cross-checks anchor details the manual does not state:

- [AppleWin](https://github.com/AppleWin/AppleWin) (GPL, used as a reference artifact only) confirms the soft-switch write/read map and the reset state (`LanguageCardUnit::kMemModeInitialState = MF_BANK2 | MF_WRITERAM`) and cites Sather *Understanding the Apple IIe* p.5-23 for the language-card prewrite rule.
- The [frozen-signal Apple_IIe_MMU_IOU reimplementation](https://github.com/frozen-signal/Apple_IIe_MMU_IOU) (CC0, schematic-derived and validated on real IIe motherboards) pins the physical row-address interleave (`MA12`), the `CXXXOUT`/`RW245`/`CASEN` equations, the MPON reset detector and the exact $C08x state machine.
- The IIe was introduced in **January 1983** ([Wikipedia](https://en.wikipedia.org/wiki/Apple_IIe), [Centre for Computing History](https://www.computinghistory.org.uk/det/209/Apple-IIe)); the exact introduction day is not asserted. The MMU/IOU customs are Synertek full-custom DIP-40 parts, Apple part numbers 341-0266 (MMU) and 341-0267 (IOU).

The MMU is the Apple IIe's memory mapper: it decodes every 6502 bus cycle, selects motherboard RAM, auxiliary-slot RAM or on-board ROM, remaps the bank-switched language-card window, multiplexes the 16-bit RAM address onto RA0-RA7, and exposes the soft-switch state on data-bus bit 7.

Implement: all ten MMU soft switches ($C000-$C00B, $C054-$C057, $C080-$C08F) with the language-card prewrite state machine, the full main/aux/ROM/I/O mapping including 80STORE/PAGE2/HIRES video-page override and ALTZP, the $D000-$DFFF physical interleave, RA0-RA7 row/column multiplexing per Table 7-9, MD7 flag readback at $C011-$C018, KBD' and CXXXOUT/CXXX decode, RW245 direction, the C800 expansion-window latch, INH' and DMA' handling, and the MPON reset detector. Do not implement: IOU functions (video counters, annunciators, paddle/speaker), the PAL timing generators (RAS'/CAS' phases, 14M domains), electrical hold times, or the data-bus multiplexers external to the MMU.

This single-clock functional reconstruction samples synchronous inputs on `clk` with synchronous active-low `rst_n`. `clk` corresponds to CPU phase 0 (PHI_0); one bus access is presented per rising edge. No electrical, half-clock, package, metastability or nanosecond timing equivalence is claimed. The real chip has no reset pin; reset state is reached through the MPON bus-sequence detector (modeled here) and equivalently through `rst_n` (wrapper convenience, not a chip pin).

## Interface (per TRM Table 7-6 pinout)

| Signal | Pin(s) | Meaning |
|---|---|---|
| `clk` | PH0 in (3) | CPU phase-0 clock; posedge = access boundary |
| `rst_n` | — | Synchronous active-low reset; MPON-equivalent power-on state (not a chip pin) |
| `a[15:0]` | 2, 26-40 | 6502 address bus input |
| `rw` | 14 | CPU read/write input; 1 = read |
| `pras_n` | 5 | Row-address strobe input from the PAL; selects row/column on RA0-RA7 |
| `inh_n` | 15 | INH' input, tied high on the IIe; low forces RAM and ROM selects off |
| `dma_n` | 16 | DMA' input; low forces the 74LS245 toward the MD bus, mapping continues |
| `ra[7:0]` | 6-13 | Multiplexed RAM address output (Table 7-9) |
| `ramen_n` | 23 (RAMEN'/CASEN) | Main-array cycle enable, active low |
| `en80_n` | 17 (EN80') | Auxiliary-array cycle enable, active low |
| `romen1_n` | 20 | ROM enable 1: $D000-$DFFF ROM reads and internal $C100-$CFFF ROM |
| `romen2_n` | 19 | ROM enable 2: $E000-$FFFF ROM reads (tied to ROMEN1' on the board) |
| `cxxxout` | 24 (C0XX) | Active high: $Cxxx cycle not served by internal ROM (card I/O page, card ROM regions) |
| `kbd_n` | 18 (KBD') | Keyboard data buffer enable, active low on reads of $C000-$C01F |
| `md7` | 21 | Soft-switch flag driven onto bus bit 7 |
| `md7_oe` | 21 | MD7 drive enable (tri-state equivalent of the open MD7 driver) |
| `rw245` | 22 (RW245) | 74LS245 direction: 1 = CPU-side bus drives MD (writes, DMA, $C020-$C0FF reads), 0 = MD drives CPU-side bus |

The exact per-pin equations follow the schematic-derived reimplementation; board-level consumers (slot I/O SELECT decoders, the 74LS245 wiring) belong to system wrappers.

## Soft switches

The $C000-$C00F writes drive an 8-bit latch addressed by `a[3:1]` with data bit `a[0]`; the MMU consumes six of the eight flags and ignores the two IOU-shared ones.

| Write | Flag | Read (bit 7) |
|---|---|---|
| $C000 / $C001 | 80STORE off/on (`store80`) | $C018 |
| $C002 / $C003 | RAMRD off/on (`ramrd`: read main/aux for $0200-$BFFF) | $C013 |
| $C004 / $C005 | RAMWRT off/on (`ramwrt`: write main/aux) | $C014 |
| $C006 / $C007 | slot ROMs / internal ROM in $C100-$C7FF (`intcx` = internal) | $C015 (1 = internal) |
| $C008 / $C009 | ALTZP off/on (main/aux zero page, stack and language card) | $C016 |
| $C00A / $C00B | internal / slot ROM at $C300 (`slotc3`) | $C017 |
| $C00C-$C00F | 80COL and ALTCHAR: latched by the real part, no MMU-observable effect | — (IOU) |

$C054/$C055 write PAGE2 (`pg2`) and $C056/$C057 write HIRES (`hires`); the IOU owns their readback ($C01C/$C01D) but the MMU needs both flags for the video-page mapping. $C010 and $C000 reads are keyboard functions: the MMU asserts KBD' for every read of $C000-$C01F (keyboard data bits 0-6 reach MD0-6 through an external buffer); the IOU supplies AKD on bit 7 at $C000.

Language-card switches: any access to $C080-$C08F updates a state register. Address bit 3 selects the $D000 bank (0 = bank 2, 1 = bank 1); `!(a[0] ^ a[1])` sets read-RAM (addresses $C080, $C083, $C088, $C08B read RAM; $C081, $C082, $C089, $C08A read ROM). Write-enable follows the prewrite rule: an even-address access ($C080, $C082, $C088, $C08A) always write-protects; an odd-address read enables writes only if it follows an odd-address read (the double-read dance), while an odd-address write preserves the current state without enabling or clearing (so a read-modify-write opcode counts its read half toward the dance, but a write access alone never enables). Reads of $C011 return the bank-2 flag and $C012 the read-RAM flag. Reset state: bank 2, read ROM, write enabled.

## Memory mapping

Selection priority per cycle (main array = `ramen_n` low, auxiliary array = `en80_n` low, both high = I/O/ROM/suppressed; the two are mutually exclusive):

1. $0400-$07FF with 80STORE, or $2000-$3FFF with 80STORE and HIRES: PAGE2 selects main/aux for reads and writes.
2. Else $D000-$FFFF or $0000-$01FF: ALTZP selects main/aux (auxiliary zero page and stack switch together with the auxiliary language card).
3. Else $0200-$BFFF: RAMRD selects for reads, RAMWRT for writes.

The 80STORE override shadows RAMRD/RAMWRT for the display pages only; with 80STORE off the RAMRD/RAMWRT range is $0200-$BFFF including the display pages.

No RAM cycle targets $C000-$CFFF. $D000-$FFFF ROM reads (`rdram` off) assert ROMEN1' ($D000-$DFFF) or ROMEN2' ($E000-$FFFF); "even when RAM is not enabled for reading, it can still be written to if it is write-enabled", so a write with `wren` on produces a RAM cycle regardless of the read select. A write-protected language-card write produces no RAM cycle at all (the write is discarded); ROM reads in $D000-$FFFF likewise suppress both RAM arrays.

Physical language-card mapping inside the 64K array (the address actually presented on RA0-RA7 for CPU accesses in $D000-$DFFF): bank 2 leaves the window at physical $D000-$DFFF, and bank 1 sends it to physical $C000-$CFFF. Equivalently, physical address bit 12 equals `a[12] ^ bank1` inside the window — $D000-$DFFF has a[12]=1 throughout, so the bank-1 flip remaps the whole 4K window cleanly. $E000-$FFFF maps directly and is unaffected by the bank flags. The remap is observable only on RA4 during column time (bit 12 is a column bit per Table 7-9).

Internal ROM serves $C300-$C3FF when `slotc3` is off (this rule takes precedence — $C300 lies inside the range below), $C100-$C7FF when `intcx` is on, and $C800-$CFFF when the expansion window is open with `intcx` on. The window opens on any access to $C300-$C3FF while internal $C3 is selected and closes on any access to $CFFF (and on reset). KBD' covers $C000-$C01F reads; CXXXOUT covers every $Cxxx cycle not served by internal ROM as defined above, including the whole $C000-$C0FF page.

## Multiplexed address

RA0-RA7 carry the row address while `pras_n` is high and the column address while low, per TRM Table 7-9:

| RA | Row | Column |
|---|---|---|
| RA0 | a[0] | a[9] |
| RA1 | a[1] | a[6] |
| RA2 | a[2] | a[10] |
| RA3 | a[3] | a[11] |
| RA4 | a[4] | mapped a[12] |
| RA5 | a[5] | a[13] |
| RA6 | a[7] | a[14] |
| RA7 | a[8] | a[15] |

The row omits a[6]; row cycling through the video refresh therefore covers all 256 row values. The column bit for RA4 is the remapped bit 12 (interleave above). RA continues to multiplex during non-RAM cycles; the phase-window tri-stating that yields the bus to the IOU during video cycles is system-timing and belongs to a wrapper.

## MD7, RW245, INH, DMA, reset

MD7 drives bit 7 during reads of $C011-$C018 with the switch states listed above (C011 bank2, C012 read-RAM, C013 RAMRD, C014 RAMWRT, C015 internal-ROM, C016 ALTZP, C017 slot-C3, C018 80STORE); bits 0-6 carry keyboard data through the KBD'-gated buffer. Reads of $C080-$C08F return memory contents (RAM byte if read-RAM, ROM byte otherwise), not flags.

RW245: 1 (CPU-side bus drives MD) during DMA' asserted, CPU writes, and reads of $C020-$C0FF; 0 (MD drives CPU-side bus) for all other reads. INH' low (unused, tied high on the IIe) forces RAM, ROM and aux selects off for that cycle. DMA' low only changes RW245; address translation continues so a bus master's addresses flow through the normal map.

Reset (rst_n low, or the MPON detector firing) sets: bank 2, read ROM, write enabled, 80STORE/RAMRD/RAMWRT off, ALTZP off, internal $C3 selected, slot ROMs in $C100-$C7FF, PAGE2/HIRES off, expansion window closed. This matches the TRM reset description ("Auxiliary RAM is disabled and the bank-switched memory space is set up to read from ROM and write to RAM, using the second bank at $D000") and AppleWin's initial state.

MPON (the real chip's reset detector) fires when an access to $FFFC follows three consecutive accesses in $0100-$01FF — the 6502 reset sequence of stack reads then reset-vector fetch. The model asserts MPON combinationally for that cycle, applies the reset state, and holds the RAM/ROM selects off while it is active. A program that reads $FFFC after stack traffic triggers MPON exactly as the real part does.

## Assumption ledger

- **A1:** The $C00x latch and $C05x latch update on the sampled access edge; the write cycle itself decodes with the old state, matching the real transparent-latch timing at bus-cycle granularity. Phase-level latch transparency is not modeled.
- **A2:** The physical $D000-$DFFF remap (`a[12] ^ bank1`, sending bank 1 to physical $C000-$CFFF) follows the schematic-derived CC0 reimplementation validated on real hardware; it is not derivable from the TRM text and has not been checked against original silicon here. Functional (logical-address) behavior is independently anchored in the TRM and AppleWin.
- **A3:** MPON detection is modeled as three sampled $0100-$01FF accesses preceding an $FFFC access, without the real φ0/Q3 phase qualification; the modeled trigger is a superset at bus-cycle granularity (a write to $FFFC can also fire it). The 6502 reset sequence satisfies both.
- **A4:** RW245 polarity is stated as a direction convention (1 = CPU bus toward MD). The real pin drives the 74LS245 DIR input whose board polarity is a schematic detail; consumers should map via the stated convention.
- **A5:** CXXXOUT for $C300-$C3FF with SLOTCXROM active (slots) follows the internal equations, which can read 0 (internal) for $C300-$C3FF when `intcx` is on even though `slotc3` selects a slot ROM there; the board-level slot-ROM enable for that corner is system decode and out of scope. The $C000-$C0FF page always asserts CXXXOUT.
- **A6:** INH' semantics (force RAM and ROM selects off) implement the "inhibits main memory" pin description plus the handwritten INH terms in the schematic-derived equations; the IIe ties the pin high so no software-observable behavior depends on it.
- **A7:** RA keeps multiplexing during non-RAM cycles and is never tri-stated in this model; the real output enable windows around PRAS'/Q3 (yielding to the IOU during video refresh) are timing behavior for the system wrapper. Pin 4 (Q3) is likewise timing-only in the real part (RA hold windows, MD7 extension into phase 1) and is omitted from the model interface; system wrappers tie it off.
- **A8:** $C00C-$C00F (80COL, ALTCHAR) are not latched in this model even though the real part's shared latch stores them, because no MMU output observes them; the IOU design must latch its own copies.
- **A9:** Read-modify-write opcodes follow the bus-level rule (each bus access counts independently; a write access preserves the write-enable state). The AppleWin GH#700 emulator workaround treats an RMW write half as enabling from a single access; if original silicon samples R/W' with a race in the LS175 clock path it may match AppleWin there. The bus-level contract is the modeled boundary; cycle-level R/W' sampling races are out of scope.

Inputs must be synchronous and stable at the rising clock edge; the mapping outputs are combinational functions of the presented access and registered switch state, so a cycle's outputs reflect the access presented that cycle. Historical firmware sequences in the testbench are derived from the TRM Appendix I Monitor listing; physical-chip comparison is not included in this sign-off.
