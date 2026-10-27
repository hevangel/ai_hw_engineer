# Chip Designs

This directory contains the historical chip designs recreated and verified by the project. Each entry records the year in which the chip was first introduced and links to the design folder.

## Chip index

Sorted by first-introduced year; within a year, entries are grouped by company and then chip number. Dating conventions used in the Year column:

- `1970*` â€” the earliest located dated documentation or announcement, not a confirmed first-shipment date; each case is discussed in the [date provenance notes](#date-provenance-notes) below.
- `By 1978*` â€” located documentation proves availability no later than that year; the exact introduction year is unknown.
- Parenthesized qualifiers describe the kind of evidence behind the date (announcement, marketing material, availability evidence, manufacturer history).

| Year | Chip | Description | Design |
|---:|---|---|---|
| 1970* (commercial; silicon 1969) | AMD Am9300 | Four-bit parallel-load/JK serial shift register; asynchronous master clear | [amd_am9300](amd_am9300/) |
| 1970* | AMD Am2501 | Four-bit binary synchronous up/down counter with preset and carry look-ahead | [amd_am2501](amd_am2501/) |
| 1970 | 74181 / SN74LS181 | 4-bit TTL arithmetic logic unit and function generator | [ttl_74xx](ttl_74xx/) |
| 1971* | AMD Am2505 | Four-by-two-bit Booth multiplier/partial-product slice; both logic polarities | [amd_am2505](amd_am2505/) |
| 1971* | AMD Am3101 | 16x4 asynchronous bipolar RAM; inverted open-collector outputs | [amd_am3101](amd_am3101/) |
| 1971 | Intel 4001 | 2048-bit mask-programmable ROM + 4-bit I/O port chip (MCS-4) | [intel_4001](intel_4001/) |
| 1971 | Intel 4002 | 320-bit RAM (256Ã—4 main + 16Ã—4 status) + 4-bit output port (MCS-4) | [intel_4002](intel_4002/) |
| 1971 | Intel 4003 | 10-bit serial-in/parallel-out shift-register I/O expander (MCS-4) | [intel_4003](intel_4003/) |
| 1971 | Intel 4004 | 4-bit microprocessor (MCS-4); authentic Busicom manual regression | [intel_4004](intel_4004/) |
| 1972 | Intel 8008 | 8-bit microprocessor (MCS-8); SCELBAL software regression | [intel_8008](intel_8008/) |
| 1973* | Intel 3205 | One-of-eight binary decoder with active-low outputs and three chip enables; MCS-8 chip-select and state decode | [intel_3205](intel_3205/) |
| 1973* | Intel 3404 | Six-bit latch as independent 4-bit and 2-bit inverting sections with separate write enables; MCS-8 address and flag latch | [intel_3404](intel_3404/) |
| 1974* | AMD Am9102 / Am9102A / Am9102B | 1024x1 asynchronous NMOS RAM; tri-state output and retained-power standby | [amd_am9102](amd_am9102/) |
| 1974 | Intel 8080 | 8-bit microprocessor; documented instruction set on a functional transaction bus | [intel_8080](intel_8080/) |
| 1974 (March announcement) | Motorola MC6800 | 8-bit microprocessor; full documented ISA (197 opcodes) passing an independent-oracle vector regression and 50 vendored hakanrw/mc6800 self-checking programs; formal bmc/prove/cover | [motorola_6800](motorola_6800/) |
| 1975 | AMD Am2901 | Four-bit ALU/register processor slice; documented Am2901A native clock phases and all 512 microinstructions | [amd_am2901](amd_am2901/) |
| 1975* (announcement) | AMD Am2902 | Four-group carry look-ahead generator; active-low P/G and hierarchical expansion | [amd_am2902](amd_am2902/) |
| 1975* (marketing) | AMD Am2909 | Four-bit microprogram sequencer; four-word return stack, separate register/direct buses and OR branching | [amd_am2909](amd_am2909/) |
| 1975* (Am9080A evidence) | AMD Am9080 / Am9080A | 8-bit processor; complete documented Am9080A instruction set and functional transaction bus | [amd_am9080](amd_am9080/) |
| 1975 | MOS Technology 6502 physical-bus variant | Documented NMOS ISA with pin/cycle timing for the Apple II revision-0 motherboard | [mos_6502_cycle](mos_6502_cycle/) |
| 1975 | MOS Technology 6502 | 8-bit microprocessor; functional and native bus engines, all opcode slots, independent timing and historical software regressions; silicon/board gates open | [mos_6502](mos_6502/) |
| 1975* (historically reported; primary launch unconfirmed) | MOS Technology 6507 | Thirteen-bit physical bus, native NMOS CPU, internal IRQ/NMI ties; package and historical software regressions | [mos_6507](mos_6507/) |
| By 1982* (preliminary datasheet; launch unconfirmed) | MOS Technology 6510 | Native NMOS CPU with integrated processor port and AEC drivers; digital and real-software gates pass, physical/reset discrepancies open | [mos_6510](mos_6510/) |
| By 1981* (preliminary datasheet; launch unconfirmed) | MOS Technology 6526 CIA | Ports, linked timers, serial, TOD/alarm and interrupts; assembled sampled CIA and eleven original KERNAL-backed Lorenz programs, Transactor read-loss profiles, original serial delay/load and 66 TOD software samples verified; physical revision qualification open | [mos_6526](mos_6526/) |
| 1975* | Intel 8251 / 8251A | Programmable synchronous/asynchronous serial interface (USART) | [intel_8251](intel_8251/) |
| 1975* / 1982* | Intel 8253 / 8254 | Three-channel programmable interval timers | [intel_8253_8254](intel_8253_8254/) |
| 1975* | Intel 8255 / 8255A | 24-line programmable peripheral interface | [intel_8255](intel_8255/) |
| By 1976* (KIM-1 manual; launch year unconfirmed) | MOS Technology 6530 RRIOT | Mask ROM, 64-byte RAM, ports and timer; both KIM-1 masks and original monitor regression | [mos_6530](mos_6530/) |
| 1976* (availability evidence) | AMD Am2911 | Four-bit microprogram sequencer; shared direct/register bus, four-word return stack | [amd_am2911](amd_am2911/) |
| 1976 | Intel 8259 / 8259A | Eight-input programmable interrupt controller; manufacturer-based request-withdrawal regression | [intel_8259](intel_8259/) |
| 1977 (manufacturer history) | AMD Am9511 | Signed integer/native floating arithmetic, conversions and transcendental processing unit | [amd_am9511](amd_am9511/) |
| 1977* (board use) | Apple II revision-0 support packages | 4116 RAM, ROM, 2513, TTL/bus interfaces and analog support; package years vary | [apple_ii_chips](apple_ii_chips/) |
| By 1977* (preliminary datasheet; launch unconfirmed) | MOS Technology 6522 VIA | Ports, input latches, handshake, timers and eight serial modes; sampled contract verified, NMOS timing open | [mos_6522](mos_6522/) |
| 1977* | Intel 8273 | HDLC/SDLC serial protocol controller; framing, NRZI, CRC, DMA and loop relay | [intel_8273](intel_8273/) |
| 1977* | Intel 8275 | DMA-fed programmable CRT controller; raster, attributes, cursor and light pen | [intel_8275](intel_8275/) |
| 1977* | Intel 8279 / 8279-5 | Programmable keyboard/display interface | [intel_8279](intel_8279/) |
| By 1978* (exact year unknown) | AMD Am2903 | Enhanced four-bit processor slice; expandable native RAM, multiply/divide/normalize, parity and sign extension | [amd_am2903](amd_am2903/) |
| By 1978* (advance information; exact launch year unknown) | AMD Am2904 | Micro/machine status registers, conditional tests, carry and shift control | [amd_am2904](amd_am2904/) |
| By 1978* (exact year unknown) | AMD Am2910 | Twelve-bit microprogram controller; five-level stack, loop counter and sixteen instructions | [amd_am2910](amd_am2910/) |
| By 1978* (exact year unknown) | AMD Am2913 | Eight-input priority interrupt expander with five output gates | [amd_am2913](amd_am2913/) |
| By 1978* (exact year unknown) | AMD Am2914 | Eight-level vectored interrupt controller; pulse capture, masks, thresholds and cascade | [amd_am2914](amd_am2914/) |
| By 1978* (exact year unknown) | AMD Am2918 | Quad D register with continuous Q and three-state Y outputs | [amd_am2918](amd_am2918/) |
| By 1978* (public announcement; exact shipment unknown) | AMD Am9517 | Four-channel multimode DMA, memory copy/fill and cascade expansion | [amd_am9517](amd_am9517/) |
| 1978 | Intel 8086 | 16-bit microprocessor; complete documented ISA and native digital BIU with independent physical-chip tests | [intel_8086](intel_8086/) |
| 1978 | Motorola MC6809 | 8-bit microprocessor; full documented ISA (pages 1/2/3, indexed postbyte indirection, TFR/EXG, MUL, long branches, FIRQ/CWAI/SYNC) passing the hardware-validated reyco2000 functional and interrupt suites; formal bmc/prove/cover | [motorola_6809](motorola_6809/) |
| 1979 (September announcement) | Motorola MC68000 | Work in progress: 16/32-bit processor; verification harness complete (SingleStepTests 680x0 suite, 1,000,060 single-instruction vectors) and RTL skeleton lint/synthesis clean; instruction classes land incrementally against the vectors | [motorola_68000](motorola_68000/) |
| 1979* (family) | Intel 8237 / 8237A | Four-channel programmable DMA controller; original IBM PC BIOS integration | [intel_8237](intel_8237/) |
| 1980 | Intel 8087 | Architectural numeric coprocessor core; 80-bit stack, original ESC instructions and transactional memory interface | [intel_8087](intel_8087/) |
| 1980* / 1982* | Intel 8272 / 8272A | Four-drive decoded-media floppy controller; FM/MFM/CRC helpers and original IBM PC BIOS/DMA regression | [intel_8272](intel_8272/) |
| By 1982* (catalog evidence; launch year unconfirmed) | MOS Technology 6532 RIOT | 128-byte RAM, two eight-bit ports, interval timer and PA7 edge interrupts | [mos_6532](mos_6532/) |
| 1982 | Intel 80286 | Work in progress: 24-bit register-execution core, ALU/shifts/branches, independent instruction vectors and original IBM AT flags-test regression | [intel_80286](intel_80286/) |
| 1983 | Apple IIe MMU (341-0266) | Firmware-validated memory mapper: main/aux/bank-switched RAM selection, soft switches, ROM decode and multiplexed DRAM address | [apple_iie_mmu](apple_iie_mmu/) |
| 1983 | Apple IIe IOU (341-0267) | Firmware-validated video machine: read/write video switches, display scanner and interleaved display-address fold, video-mode soft switches, keyboard strobe/auto-repeat, annunciator/speaker/cassette outputs | [apple_iie_iou](apple_iie_iou/) |
| 1983 | Apple IIe timing PAL (PAL16R8) | Apple-programmed timing generator: Ï†0/Ï†1 CPU clocks, asymmetric Q3 strobe, PRAS'/PCAS' DRAM strobes with CAS gating, LDPS' video load and the 7 MHz dot clock | [apple_iie_pal](apple_iie_pal/) |
| 1983 | Ricoh RP2A03 / RP2A07 | NES CPU: native NMOS 6502 with decimal disabled, APU (pulse, triangle, noise, DMC, frame sequencer), OAM/DMC DMA, controller I/O; NTSC and PAL; independent CPU vectors, nestest and blargg test ROMs | [ricoh_2a03](ricoh_2a03/) |
| 1983 | Ricoh RP2C02 / RP2C07 | NES PPU: dot-level background pipeline, sprite evaluation with the overflow bug, sprite-0 hit, scroll registers, vblank/NMI races; NTSC and PAL; reference-renderer frame compare and blargg PPU test ROMs | [ricoh_2c02](ricoh_2c02/) |
| By 1983* (dated manufacturer description; launch unconfirmed) | MOS Technology 6560 / 6561 VIC | VIC-20 video/sound; complete digital chip (registers, PAL/NTSC raster/interlace, fetch/pixels, light pen, sound) matches MAME per clock and boots original VIC-20 firmware; analog outputs/POT conversion and physical validation pending | [mos_6560](mos_6560/) |
| By 1983* (dated manufacturer description; launch unconfirmed) | MOS Technology 6567 / 6569 VIC-II | C64 video controller; dot-level digital chip for 6569, 6567R8, 6567R56A, 8565 and 8562 matches MAME per fetch, bus cycle and pixel; original C64 software and physical validation pending | [mos_6567](mos_6567/) |
| By 1983* (dated manufacturer description; launch unconfirmed) | MOS Technology 6581 / 8580 SID | C64 sound; digital core (oscillators, noise, envelopes, sync/ring, OSC3/ENV3/POT, bus latch) matches reSIDfp per clock for both models; analog DAC/filter stage and original software pending | [mos_6581](mos_6581/) |
| 1983 | Apple IIe MMU (341-0266) | Full-custom memory mapper: main/aux/bank-switched RAM selection, soft switches, ROM decode and multiplexed DRAM address | [apple_iie_mmu](apple_iie_mmu/) |
| 1983 | Apple IIe IOU (341-0267) | Full-custom video machine: display scanner and interleaved display-address fold, video-mode soft switches, keyboard strobe/auto-repeat, annunciator/speaker/cassette outputs | [apple_iie_iou](apple_iie_iou/) |
| 1983 | Apple IIe timing PAL (PAL16R8) | Apple-programmed timing generator: φ0/φ1 CPU clocks, asymmetric Q3 strobe, PRAS'/PCAS' DRAM strobes with CAS gating, LDPS' video load and the 7 MHz dot clock | [apple_iie_pal](apple_iie_pal/) |
| By 1986* (bibliographic evidence; launch unconfirmed) | MOS Technology 8520 CIA | Amiga peripheral controller: 6526 core with binary 24-bit TOD event counter and 8520 timer/interrupt timing; matches MAME except nine classified residuals; Amiga software pending | [mos_8520](mos_8520/) |

## Date provenance notes

A year marked with an asterisk (`*`) is the earliest located dated documentation or announcement, not a claim of an exact commercial launch date; availability may have preceded or followed that document, and the uncertainty is retained rather than guessed. The notes below record the sources behind each index date and are grouped by company and chip series.

### AMD â€” Am9300
### MOS — 6522, 6530, 6532 and reconstruction series

The 6522 entry uses a **by 1977** bound from the [November 1977 MOS preliminary datasheet](https://www.6502.org/documents/datasheets/mos/mos_6522_preliminary_nov_1977.pdf), not an exact shipment date. See the [VIA history and unresolved timing discrepancies](mos_6522/README.md).

The 6530 entry uses **by 1976** from the manufacturer's [August 1976 KIM-1 User Manual](https://bitsavers.org/components/mosTechnology/kim-1/6500-15B_KIM-1_Users_Manual_197608.pdf). Its October 1975 firmware revision does not establish an exact chip launch date; see the [RRIOT history and mask-specific reconstruction](mos_6530/README.md).

The 6532 year is an availability bound from the [1982 MOS Data Catalog](https://bitsavers.trailing-edge.com/components/mosTechnology/_dataBooks/1982_MOS_Technology_Data_Catalog.pdf), not a claim that it launched in 1982. The archived datasheet is assigned 1976 by a secondary catalog, but the date is not established on the scan; see the [chip history](mos_6532/README.md). The requested sequential chip reconstructions followed by Atari 2600, Commodore 64, NES and Super Nintendo are tracked in the [MOS series ledger](../plans/mos_historical_series.md).

The 6560/6561, 6567/6569 and 6581 entries are bounded by later printings of Commodore manuals that are explicitly dated 1983 (the VIC-20 Programmer's Reference Guide sixth printing and the C64 Programmer's Reference Guide eighth printing); no earlier dated primary document was located, and the 6569 and 8580 revisions are not dated by them. See each chip README.

### AMD — Am9300

The AMD Am9300 entry uses **1970*** for commercial availability, separating it from first working silicon in **1969**. First-person and AMD-sourced accounts differ on the exact first-shipment milestone; see the [chip history and source discussion](amd_am9300/README.md). The ongoing [historical AMD series ledger](../plans/amd_historical_series.md) records the remaining requested designs and their actual completion state.

### Apple â€” IIe MMU and IOU

The Apple IIe MMU, IOU and timing-PAL entries record **1983**, the IIe's introduction month being January 1983 per the [IIe historical summary](https://en.wikipedia.org/wiki/Apple_IIe) and the [Centre for Computing History](https://www.computinghistory.org.uk/det/209/Apple-IIe); the exact introduction day is not asserted. The MMU and IOU (Apple 341-0266 / 341-0267) are Synertek-manufactured full-custom DIP-40 chips and the timing generator is an Apple-programmed PAL16R8. Technical behavior follows the [Apple IIe Technical Reference Manual, 2nd ed.](https://archive.org/details/Apple_IIe_Technical_Reference_Manual) and is cross-checked against the schematic-derived CC0 [frozen-signal reimplementation](https://github.com/frozen-signal/Apple_IIe_MMU_IOU) (MMU/IOU only); see each design's [specification](apple_iie_mmu/spec/spec.md) ([IOU](apple_iie_iou/spec/spec.md), [PAL](apple_iie_pal/spec/spec.md)) for the assumption ledgers.

### Intel â€” MCS-4 family (4001, 4002, 4003, 4004)

The Intel 4001 entry records **1971**, the year the MCS-4 family (4004 CPU, 4001 ROM + I/O, 4002 RAM, 4003 shift register) reached the market. The family was developed for the Busicom 141-PF calculator and announced through Intel's advertisement in the November 15, 1971 issue of *Electronic News*, the date the industry treats as the first commercial microprocessor announcement ([EDN](https://www.edn.com/intel-4004-is-announced-november-15-1971/), [Computer History Museum](https://www.computerhistory.org/tdih/november/15/)); the November 1971 [MCS-4 data sheet](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf) is the earliest located Intel document describing the 4001 as the set's mask-programmable program storage. The November 15 date is specifically the advertisement's publication date and some accounts frame earlier mentions differently; the year itself is not in dispute. Technical behavior is sourced from the [MCS-4 Users Manual scan](https://archive.org/details/bitsavers_intelMCS4M_18342130) and the design's [specification](intel_4001/spec/spec.md).

The Intel 4002 entry records the same **1971** family year as the rest of the MCS-4 set; see the Intel 4001 note above for the family-announcement sources. No separate month-level launch claim is made.

The Intel 4003 entry records **1971**: it is the I/O expander of the MCS-4 chip set (4004 CPU, 4001 ROM, 4002 RAM, 4003 shift register) announced on November 15, 1971 in Intel's *Electronic News* advertisement, and the November 1971 MCS-4 data catalog already contains the 4003 data sheet, so the part shipped with the family from launch. Secondary retellings differ on how prominently the support chips figured in the original ad, and the exact volume-shipping date is not established; the year is retained rather than a month-level claim. Despite informal summaries calling it a 16-bit part, the [MCS-4 Users Manual (February 1973)](https://archive.org/stream/bitsavers_intelMCS4M_18342130/MCS-4_UsersManual_Feb73_djvu.txt), the [November 1971 data sheet scan](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf) and [IEEE's "The History of the 4004"](https://www.computer.org/csdl/magazine/mi/1996/06/m6010/13rRUytWFdY) uniformly describe a 10-bit serial-in/parallel-out, serial-out static shift register; technical behavior is summarized in the design's [specification](intel_4003/spec/spec.md) and [historical overview](intel_4003/README.md).

The Intel 4004 entry records **1971**: Intel announced the 4004 on November 15, 1971 in Electronic News as the MCS-4 central processor developed for the Busicom 141-PF calculator, making it the first commercially available microprocessor, per the [Intel 4004 historical summary](https://en.wikipedia.org/wiki/Intel_4004) and the [Intel 4004 anniversary project](https://www.4004.com/). Technical behavior is sourced from the [scanned MCS-4 user manual](http://codeabbey.github.io/heavy-data-1/msc4-manual.pdf), instruction-set transcriptions at the [e4004 project](http://e4004.szyc.org/iset.html) and [pastraiser](https://pastraiser.com/cpu/i4004/i4004_opcodes.html), and cross-checked against the [MAME MCS-40 core](https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp), summarized in the design's [specification](intel_4004/spec/spec.md).

### Intel â€” MCS-8 (3205, 3404, 8008)

The Intel 3205 entry uses **1973*** as the earliest located dated Intel documentation: the [November 1973 MCS-8 Users Manual](../references/intel_mcs8_users_manual_nov1973.pdf) prints the decoder's truth table (scan page 32) and uses 3205s throughout the SIM8-01 for 8008 state-line decoding and memory chip selects. The same manual's service note that SIM8-01 boards built prior to October 1972 must be modified shows the MCS-8 module was already in field use, so the decoder's availability may have been earlier; the uncertainty is retained rather than guessed. Function follows the combined [Intel 3205/3404 data sheet](../references/intel_3205_3404_datasheet.pdf); see the [design overview](intel_3205/README.md).

The Intel 3404 entry uses **1973*** on the same evidence: the MCS-8 manual latches the 8008's time-multiplexed address bytes and the INP flag output in 3404s across the SIM8-01 (scan page 33), and the same pre-October-1972 board-revision note implies earlier availability; the uncertainty is retained rather than guessed. The latch's transparent-while-low, store-on-rising-edge function and its independent 4-bit and 2-bit organization follow the combined [Intel 3205/3404 data sheet](../references/intel_3205_3404_datasheet.pdf); the section bit mapping and the synchronous reset artifact are recorded in the design's assumption ledger, see the [design overview](intel_3404/README.md).

The Intel 8008 entry records **1972**, with Intel dating its introduction to April 1972 in its [8008 history](https://www.intel.com/content/www/us/en/history/virtual-vault/articles/the-8008.html). Technical behavior follows the downloaded [MCS-8 Users Manual](intel_8008/references/intel_mcs8_users_manual_nov1973.md) and is checked against SCELBAL and the independent SIMH model; see the [design overview](intel_8008/README.md).

### Intel â€” 8080

The Intel 8080 entry records **1974**, following Intel's [manufacturer history](https://www.intel.com/content/www/us/en/newsroom/news/50-years-ago-the-influential-intel-8080.html). Announcement and release are distinguished differently in month-level retellings; no exact month is claimed here. The initial design implements documented instructions through a functional transaction bus, with Intel-specific ANA/ANI flags; native pin timing and undocumented aliases remain separate milestones. See the [design overview](intel_8080/README.md).

### Intel â€” 8086

The Intel 8086 entry records **1978**; Intel dates its introduction to June 8, 1978 in its [manufacturer history](https://timeline.intel.com/1978/the-beginning-of-a-legend%3A-the-8086). This design implements the complete documented instruction set, interrupts and a six-byte prefetch BIU with minimum/maximum-mode digital pins. Independent physical-chip vectors, original DEBUG.COM, formal checks and native bus tests verify the implementation; original EU cycle counts and electrical timing are outside its RTL contract. See the [chip overview](intel_8086/README.md). Its standalone software regression runs unchanged Microsoft DEBUG.COM through the execution unit and both native bus modes.

### Motorola — 6800, 6809, 68000

The Motorola 6800 entry records **1974 (March announcement)**: the [M6800 Microcomputer System announcement](https://en.wikipedia.org/wiki/Motorola_6800) is dated March 1974 with full production by year end; secondary sources differ on the exact day within March 1974, so only the month is claimed. Technical behavior follows the [M6800 Programming Reference Manual M68PRM(D), November 1976](https://bitsavers.trailing-edge.com/components/motorola/6800/Motorola_M6800_Programming_Reference_Manual_M68PRM(D)_Nov76.pdf) (bitsavers). See the [chip overview](motorola_6800/README.md).

The Motorola 6809 entry records **1978**; secondary sources agree on the year but differ on the month, so only the year is claimed. Technical behavior follows the Motorola MC6809 data sheet and programming manual, cross-checked against [MAME's m6809 core](https://github.com/mamedev/mame/blob/master/src/devices/cpu/m6809/m6809.h) (vector map) and the hardware-validated [reyco2000/6809_6309_code_tester](https://github.com/reyco2000/6809_6309_code_tester) programs. See the [chip overview](motorola_6809/README.md).

The Motorola 68000 entry records **1979 (September announcement)**; the September 1979 announcement is the commonly cited date and the exact day is not asserted. The design is work in progress: verification harness complete (SingleStepTests 680x0 suite, 1,000,060 single-instruction vectors), RTL skeleton lint/synthesis clean, instruction classes landing incrementally. See the [chip overview](motorola_68000/README.md).

### Intel — support and peripheral devices (8237, 8251, 8253/8254, 8255, 8259, 8272, 8273, 8275, 8279)

The Intel 8237/8237A entry records **1979*** for the original 8237 family: the [May 1979 Intel 8237/8237-2 datasheet](https://web.cecs.pdx.edu/~mpj/llp/references/Intel-8237-dma.pdf) is dated by the [technical specification index](https://wiki.osdev.org/Technical_Specifications), and the [family history](https://en.wikipedia.org/wiki/Intel_8237) cites an Intel *Preview* announcement in May/June 1979. The exact introduction date of the later 8237A revision is not established; the year is not an A-revision launch claim. The design follows the [Intel 8237A datasheet](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf); implementation scope and uncertainties are documented in the [chip overview](intel_8237/README.md).

The Intel 8251/8251A entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. The device appears as the 8251 Programmable Communication Interface in Intel's [September 1975 8080 Microcomputer Systems User's Manual](https://archive.org/details/bitsavers_intelMCS80ocomputerSystemsUsersManual197509_43049640). Dated Intel references for the later variants are narrower and later: per the [8251 historical summary](https://en.wikipedia.org/wiki/Intel_8251), an industrial-grade `ID8251` appears in the March/April 1979 *Intel Preview* and the 8251A in the May/June 1980 issue, neither of which is necessarily an introduction date. Availability may therefore have preceded or followed those documents, so the uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel 8251A datasheet reproduction](https://www.alldatasheet.com/datasheet-pdf/pdf/66096/INTEL/8251A.html), cross-checked against the [NJIT EE395 8251A programming notes](https://web.njit.edu/~gilhc/EE395/8251int.htm), and summarized in the design's [specification](intel_8251/spec/spec.md).

The Intel 8253/8254 entry uses **1975*** and **1982*** as the earliest located dated Intel documentation for each device, not as exact commercial launch claims. The 8253 appears in Intel's [September 1975 8080 systems manual](https://archive.org/details/intel8080microco00inte), while Intel's [1982 Systems Data Catalog](https://archive.org/stream/bitsavers_inteldataBCatalog_75793335/1982_Systems_Data_Catalog_djvu.txt) contains preliminary 8254 material. Availability may have preceded those documents, so the uncertainty is retained. Technical behavior is documented in the design's [specification](intel_8253_8254/spec/spec.md). Original IBM Model 30 POST also validates Mode 0 count rewrites; the [failure note](../failure_notes/2026-10-15-pit-mode0-rearm.md) records the required OUT edge and added regression.

The Intel 8255 entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. Historical summaries place development in the first half of the 1970s, a September 1975 Intel systems manual documents the device, and the [Computer History Museum catalogs an Intel 8255A applications note from 1976](https://www.computerhistory.org/collections/catalog/102671978). The precise introduction date may be earlier; this uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel datasheet reproduction](https://www.cambridge.org/core/books/ibmpc-in-the-laboratory/8255-programmable-peripheral-interface-data-sheets/1B5F5ABF95580D00D463BA07BF9A892A) and the design's [specification](intel_8255/spec/spec.md).

The Intel 8259/8259A entry records **1976**, the year the 8259 was introduced as part of Intel's MCS-85 family, per the [8259 historical summary](https://en.wikipedia.org/wiki/Intel_8259). The exact commercial launch date within 1976 was not established, so the index records the year rather than a month-level date. The later 8259A added 8086/8088 mode and became a fixture of the IBM PC/AT interrupt architecture. Technical behavior is sourced from the [Intel 8259A datasheet reproduction](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf) and the [Intel "Programming the 8259A" application note](http://www.idc-online.com/technical_references/pdfs/electronic_engineering/Programming_THE_8259A.pdf), summarized in the design's [specification](intel_8259/spec/spec.md).

The Intel 8272/8272A entry uses **1980*** and **1982*** as the earliest located dated Intel documentation, not exact commercial launch claims. A January 1980 Intel 8272 sheet is reproduced in the [CompuPro Disk 1 manual](https://www.bitsavers.org/pdf/compupro/Storage/171_DISK1/171F_Disk_1_Technical_Manual_1982.pdf); the [8272A preliminary sheet](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf) carries Â©1982. Exact first-shipment dates were not established. See the [design overview](intel_8272/README.md) for its decoded-media scope and sources.

The Intel 8273 entry uses **1977*** for announced availability: Intel's [advertisement in Electronic Design, November 22, 1977](https://device.report/m/8bc5b6376694b97e23c2f7405d8292f666953225fb3eb6506aa146bfc391ae7c) lists the 8273 with fourth-quarter 1977 availability. An exact first-shipment date was not established. The [design overview](intel_8273/README.md) describes the sourced programming model, real serial framing and functional boundaries.

The Intel 8275 entry records **1977*** for public introduction: the contemporary [May 26, 1977 Electronics report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new controller and says sample quantities are forthcoming. This does not establish an exact first-shipment date. The design follows Intel's [8275 AFN-00224B datasheet scan](intel_8275/references/intel_8275.pdf); see the [overview](intel_8275/README.md) and [specification](intel_8275/spec/spec.md) for sources and implementation boundaries.

The 8279 entry uses **1977*** because a contemporary [May 26, 1977 *Electronics* report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new 8279 keyboard/display interface. This establishes public availability by that date but not an exact first-shipment date. The digital programming model follows the [Intel 8279/8279-5 data sheet](https://datasheets.pl/elementy_czynne/IC/8/8279.pdf) and is detailed in the [design specification](intel_8279/spec/spec.md).

### MOS Technology â€” 6502

The MOS Technology 6502 entry records **1975**, supported by the [IEEE historical exhibit](https://history.ieee.org/programs/ieee-global-museum/microchips-that-shook-the-world/). The exact commercial introduction date is not asserted; the index records the year rather than a month-level date. Instruction behavior is grounded in MOS Technology's [January 1976 programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf), and cycle timing must be checked against its [hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf); see the [chip overview](mos_6502/README.md).

### Texas Instruments â€” 74181

The 74181 entry uses **1970** as the introduction year. Historical references differ on the exact month, so the index intentionally records the year rather than a month-level date. The year is supported by the [74181 historical summary](https://en.wikipedia.org/wiki/74181) and [Ken Shirriff's historical analysis](https://www.righto.com/2017/03/inside-vintage-74181-alu-chip.html). Technical device information is available from [Texas Instruments' SN54S181 product page](https://www.ti.com/product/SN54S181) and the design's [specification](ttl_74xx/spec/spec.md).

Source material is summarized and rephrased for licensing compliance.

## Design documentation

Each chip folder contains its own historical overview, specification, implementation plans, RTL, verification environment, formal properties, scripts, and reports. Start with the chip folder's `README.md` for historical context and links to its Markdown documentation.

## System integration updates

The [1983 IBM XT platform](../system/ibm_pc_xt_5160/README.md) uses the Intel
8086 core's additional ESC/WAIT observation outputs and the Intel 8087's
execution-gated numeric datapaths. The chip introduction years and respective
architectural verification boundaries above remain unchanged.

### Apple â€” revision-0 support packages

The grouped support-package entry records **1977 board use**, established by
the [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf),
rather than asserting a common first-introduced year for the individual TTL,
RAM, ROM and analog parts. Individual variant dates remain unestablished;
see the [package overview](apple_ii_chips/README.md).

Apple IIe board integration now exercises the unchanged original ROM, BASIC and
80-column firmware. Primary-manual corrections to Cxxx ROM selection and
read-side video switches are documented in the [platform](../system/apple_iie/)
and [post-mortem](../failure_notes/2026-10-19-apple-iie-rom-switches.md).

## Numbered 74-series digital functions

All functions are grouped in [ttl_74xx](ttl_74xx/README.md). Unknown* records an unestablished first-introduced year; manufacturer sources and normalized interface contracts are linked per part. The extended inventory includes numbers above 74299 and wide-bus parts. See the
[coverage report](ttl_74xx/report/extended_report.md) for pending digital functions
and analog exclusions. Pending entries are not completed designs.

| First introduced | Chip | Function | Design/specification |
|---|---|---|---|
| Unknown* | 74x00 | quad 2-input NAND gate | [ttl_74x00](ttl_74xx/spec/chips/ttl_74x00.md) |
| Unknown* | 74x01 | quad 2-input NAND gate; different pinout for 74H01 | [ttl_74x01](ttl_74xx/spec/chips/ttl_74x01.md) |
| Unknown* | 74x02 | quad 2-input NOR gate | [ttl_74x02](ttl_74xx/spec/chips/ttl_74x02.md) |
| Unknown* | 74x03 | quad 2-input NAND gate | [ttl_74x03](ttl_74xx/spec/chips/ttl_74x03.md) |
| Unknown* | 74x04 | hex inverter gate | [ttl_74x04](ttl_74xx/spec/chips/ttl_74x04.md) |
| Unknown* | 74x05 | hex inverter gate | [ttl_74x05](ttl_74xx/spec/chips/ttl_74x05.md) |
| Unknown* | 74x06 | hex inverter gate | [ttl_74x06](ttl_74xx/spec/chips/ttl_74x06.md) |
| Unknown* | 74x07 | hex buffer gate | [ttl_74x07](ttl_74xx/spec/chips/ttl_74x07.md) |
| Unknown* | 74x08 | quad 2-input AND gate | [ttl_74x08](ttl_74xx/spec/chips/ttl_74x08.md) |
| Unknown* | 74x09 | quad 2-input AND gate | [ttl_74x09](ttl_74xx/spec/chips/ttl_74x09.md) |
| Unknown* | 74x10 | triple 3-input NAND gate | [ttl_74x10](ttl_74xx/spec/chips/ttl_74x10.md) |
| Unknown* | 74x11 | triple 3-input AND gate | [ttl_74x11](ttl_74xx/spec/chips/ttl_74x11.md) |
| Unknown* | 74x12 | triple 3-input NAND gate | [ttl_74x12](ttl_74xx/spec/chips/ttl_74x12.md) |
| Unknown* | 74x13 | dual 4-input NAND gate | [ttl_74x13](ttl_74xx/spec/chips/ttl_74x13.md) |
| Unknown* | 74x14 | hex inverter gate | [ttl_74x14](ttl_74xx/spec/chips/ttl_74x14.md) |
| Unknown* | 74x15 | triple 3-input AND gate | [ttl_74x15](ttl_74xx/spec/chips/ttl_74x15.md) |
| Unknown* | 74x16 | hex inverter gate | [ttl_74x16](ttl_74xx/spec/chips/ttl_74x16.md) |
| Unknown* | 74x17 | hex buffer gate | [ttl_74x17](ttl_74xx/spec/chips/ttl_74x17.md) |
| Unknown* | 74x18 | dual 4-input NAND gate | [ttl_74x18](ttl_74xx/spec/chips/ttl_74x18.md) |
| Unknown* | 74x19 | hex inverter gate | [ttl_74x19](ttl_74xx/spec/chips/ttl_74x19.md) |
| Unknown* | 74x20 | dual 4-input NAND gate | [ttl_74x20](ttl_74xx/spec/chips/ttl_74x20.md) |
| Unknown* | 74x21 | dual 4-input AND gate | [ttl_74x21](ttl_74xx/spec/chips/ttl_74x21.md) |
| Unknown* | 74x22 | dual 4-input NAND gate | [ttl_74x22](ttl_74xx/spec/chips/ttl_74x22.md) |
| Unknown* | 74x23 | dual 4-input NOR gate with strobe, one gate expandable with 74x60 | [ttl_74x23](ttl_74xx/spec/chips/ttl_74x23.md) |
| Unknown* | 74x24 | quad 2-input NAND gate | [ttl_74x24](ttl_74xx/spec/chips/ttl_74x24.md) |
| Unknown* | 74x25 | dual 4-input NOR gate with strobe | [ttl_74x25](ttl_74xx/spec/chips/ttl_74x25.md) |
| Unknown* | 74x26 | quad 2-input NAND gate | [ttl_74x26](ttl_74xx/spec/chips/ttl_74x26.md) |
| Unknown* | 74x27 | triple 3-input NOR gate | [ttl_74x27](ttl_74xx/spec/chips/ttl_74x27.md) |
| Unknown* | 74x28 | quad 2-input NOR gate | [ttl_74x28](ttl_74xx/spec/chips/ttl_74x28.md) |
| Unknown* | 74x29 | dual 4-input NOR gate | [ttl_74x29](ttl_74xx/spec/chips/ttl_74x29.md) |
| Unknown* | 74x30 | single 8-input NAND gate | [ttl_74x30](ttl_74xx/spec/chips/ttl_74x30.md) |
| Unknown* | 74x32 | quad 2-input OR gate | [ttl_74x32](ttl_74xx/spec/chips/ttl_74x32.md) |
| Unknown* | 74x33 | quad 2-input NOR gate | [ttl_74x33](ttl_74xx/spec/chips/ttl_74x33.md) |
| Unknown* | 74x34 | hex buffer gate | [ttl_74x34](ttl_74xx/spec/chips/ttl_74x34.md) |
| Unknown* | 74x35 | hex buffer gate | [ttl_74x35](ttl_74xx/spec/chips/ttl_74x35.md) |
| Unknown* | 74x36 | quad 2-input NOR gate (different pinout than 7402) | [ttl_74x36](ttl_74xx/spec/chips/ttl_74x36.md) |
| Unknown* | 74x37 | quad 2-input NAND gate | [ttl_74x37](ttl_74xx/spec/chips/ttl_74x37.md) |
| Unknown* | 74x38 | quad 2-input NAND gate | [ttl_74x38](ttl_74xx/spec/chips/ttl_74x38.md) |
| Unknown* | 74x39 | quad 2-input NAND gate (different pinout than 7438) | [ttl_74x39](ttl_74xx/spec/chips/ttl_74x39.md) |
| Unknown* | 74x40 | dual 4-input NAND gate | [ttl_74x40](ttl_74xx/spec/chips/ttl_74x40.md) |
| Unknown* | 74x41 | BCD to decimal decoder / Nixie tube driver | [ttl_74x41](ttl_74xx/spec/chips/ttl_74x41.md) |
| Unknown* | 74x42 | BCD to decimal decoder | [ttl_74x42](ttl_74xx/spec/chips/ttl_74x42.md) |
| Unknown* | 74x43 | excess-3 to decimal decoder | [ttl_74x43](ttl_74xx/spec/chips/ttl_74x43.md) |
| Unknown* | 74x44 | Gray code to decimal decoder | [ttl_74x44](ttl_74xx/spec/chips/ttl_74x44.md) |
| Unknown* | 74x45 | BCD to decimal decoder/driver | [ttl_74x45](ttl_74xx/spec/chips/ttl_74x45.md) |
| Unknown* | 74x46 | BCD to 7-segment display decoder/driver | [ttl_74x46](ttl_74xx/spec/chips/ttl_74x46.md) |
| Unknown* | 74x47 | BCD to 7-segment decoder/driver | [ttl_74x47](ttl_74xx/spec/chips/ttl_74x47.md) |
| Unknown* | 74x48 | BCD to 7-segment decoder/driver | [ttl_74x48](ttl_74xx/spec/chips/ttl_74x48.md) |
| Unknown* | 74x49 | BCD to 7-segment decoder/driver | [ttl_74x49](ttl_74xx/spec/chips/ttl_74x49.md) |
| Unknown* | 74x50 | dual 2-2-input AND-OR-Invert gate, one gate expandable | [ttl_74x50](ttl_74xx/spec/chips/ttl_74x50.md) |
| Unknown* | 7451 | dual 2-2-input AND-OR-Invert (AOI) gate | [ttl_7451](ttl_74xx/spec/chips/ttl_7451.md) |
| Unknown* | 74L51 | 3-3-input AND-OR-Invert gate and 2-2-input AND-OR-Invert gate | [ttl_74l51](ttl_74xx/spec/chips/ttl_74l51.md) |
| Unknown* | 74x52 | 3-2-2-2-input AND-OR gate, expandable with 74x61 | [ttl_74x52](ttl_74xx/spec/chips/ttl_74x52.md) |
| Unknown* | 7453 | 2-2-2-2-input AND-OR-Invert gate, expandable | [ttl_7453](ttl_74xx/spec/chips/ttl_7453.md) |
| Unknown* | 74H53 | 3-2-2-2-input AND-OR-Invert gate, expandable | [ttl_74h53](ttl_74xx/spec/chips/ttl_74h53.md) |
| Unknown* | 7454 | 2-2-2-2-input AND-OR-Invert gate | [ttl_7454](ttl_74xx/spec/chips/ttl_7454.md) |
| Unknown* | 74H54 | 3-2-2-2-input AND-OR-Invert gate | [ttl_74h54](ttl_74xx/spec/chips/ttl_74h54.md) |
| Unknown* | 74L54 | 3-3-2-2-input AND-OR-Invert gate | [ttl_74l54](ttl_74xx/spec/chips/ttl_74l54.md) |
| Unknown* | 74x55 | 4-4-input AND-OR-Invert gate, 74H55 is expandable | [ttl_74x55](ttl_74xx/spec/chips/ttl_74x55.md) |
| Unknown* | 74x56 | 50:1 frequency divider | [ttl_74x56](ttl_74xx/spec/chips/ttl_74x56.md) |
| Unknown* | 74x57 | 60:1 frequency divider | [ttl_74x57](ttl_74xx/spec/chips/ttl_74x57.md) |
| Unknown* | 74x58 | 3-3-input AND-OR gate and 2-2-input AND-OR gate | [ttl_74x58](ttl_74xx/spec/chips/ttl_74x58.md) |
| Unknown* | 74x59 | dual 3-2-input AND-OR-Invert gate | [ttl_74x59](ttl_74xx/spec/chips/ttl_74x59.md) |
| Unknown* | 74x60 | dual 4-input expander for 74x23, 74x50, 74x53, 74x55 | [ttl_74x60](ttl_74xx/spec/chips/ttl_74x60.md) |
| Unknown* | 74x61 | triple 3-input expander for 74x52 | [ttl_74x61](ttl_74xx/spec/chips/ttl_74x61.md) |
| Unknown* | 74x62 | 3-3-2-2-input AND-OR expander for 74x50, 74x53, 74x55 | [ttl_74x62](ttl_74xx/spec/chips/ttl_74x62.md) |
| Unknown* | 74x63 | hex current sensing interface gates | [ttl_74x63](ttl_74xx/spec/chips/ttl_74x63.md) |
| Unknown* | 74x64 | 4-3-2-2-input AND-OR-Invert gate | [ttl_74x64](ttl_74xx/spec/chips/ttl_74x64.md) |
| Unknown* | 74x65 | 4-3-2-2 input AND-OR-Invert gate | [ttl_74x65](ttl_74xx/spec/chips/ttl_74x65.md) |
| Unknown* | 74x67 | AND gated J-K master-slave flip-flop, asynchronous preset and clear (improved 74L72) | [ttl_74x67](ttl_74xx/spec/chips/ttl_74x67.md) |
| Unknown* | 74L68 | dual J-K flip-flop, asynchronous clear (improved 74L73) | [ttl_74l68](ttl_74xx/spec/chips/ttl_74l68.md) |
| Unknown* | 74LS68 | dual 4-bit decade counters | [ttl_74ls68](ttl_74xx/spec/chips/ttl_74ls68.md) |
| Unknown* | 74L69 | dual J-K flip-flop, asynchronous preset, shared clock and clear | [ttl_74l69](ttl_74xx/spec/chips/ttl_74l69.md) |
| Unknown* | 74LS69 | dual 4-bit binary counters | [ttl_74ls69](ttl_74xx/spec/chips/ttl_74ls69.md) |
| Unknown* | 74x70 | AND-gated positive-edge-triggered J-K flip-flop, asynchronous preset and clear | [ttl_74x70](ttl_74xx/spec/chips/ttl_74x70.md) |
| Unknown* | 74H71 | AND-OR-gated J-K master-slave flip-flop, preset | [ttl_74h71](ttl_74xx/spec/chips/ttl_74h71.md) |
| Unknown* | 74L71 | AND-gated R-S master-slave flip-flop, preset and clear | [ttl_74l71](ttl_74xx/spec/chips/ttl_74l71.md) |
| Unknown* | 74x72 | AND gated J-K master-slave flip-flop, asynchronous preset and clear | [ttl_74x72](ttl_74xx/spec/chips/ttl_74x72.md) |
| Unknown* | 74x73 | dual J-K flip-flop, asynchronous clear | [ttl_74x73](ttl_74xx/spec/chips/ttl_74x73.md) |
| Unknown* | 74x74 | dual D positive-edge-triggered flip-flop, asynchronous clear & preset, Q & /Q outputs | [ttl_74x74](ttl_74xx/spec/chips/ttl_74x74.md) |
| Unknown* | 74x75 | 4-bit bistable latch, complementary outputs | [ttl_74x75](ttl_74xx/spec/chips/ttl_74x75.md) |
| Unknown* | 74x76 | dual J-K flip-flop, asynchronous preset and clear | [ttl_74x76](ttl_74xx/spec/chips/ttl_74x76.md) |
| Unknown* | 74x77 | 4-bit bistable latch | [ttl_74x77](ttl_74xx/spec/chips/ttl_74x77.md) |
| Unknown* | 74H78 | dual positive-pulse-triggered J-K flip-flop, preset, shared clock and clear | [ttl_74h78](ttl_74xx/spec/chips/ttl_74h78.md) |
| Unknown* | 74L78 | dual positive-pulse-triggered J-K flip-flop, preset, shared clock and clear | [ttl_74l78](ttl_74xx/spec/chips/ttl_74l78.md) |
| Unknown* | 74LS78 | dual negative-edge-triggered J-K flip-flop, preset, shared clock and clear | [ttl_74ls78](ttl_74xx/spec/chips/ttl_74ls78.md) |
| Unknown* | 74x79 | dual D positive-edge-triggered flip-flop, asynchronous preset and clear | [ttl_74x79](ttl_74xx/spec/chips/ttl_74x79.md) |
| Unknown* | 74x80 | gated full adder | [ttl_74x80](ttl_74xx/spec/chips/ttl_74x80.md) |
| Unknown* | 74x81 | 16-bit RAM | [ttl_74x81](ttl_74xx/spec/chips/ttl_74x81.md) |
| Unknown* | 74x82 | 2-bit binary full adder | [ttl_74x82](ttl_74xx/spec/chips/ttl_74x82.md) |
| Unknown* | 74x83 | 4-bit binary full adder | [ttl_74x83](ttl_74xx/spec/chips/ttl_74x83.md) |
| Unknown* | 74x84 | 16-bit RAM | [ttl_74x84](ttl_74xx/spec/chips/ttl_74x84.md) |
| Unknown* | 74x85 | 4-bit magnitude comparator | [ttl_74x85](ttl_74xx/spec/chips/ttl_74x85.md) |
| Unknown* | 74x86 | quad 2-input XOR gate | [ttl_74x86](ttl_74xx/spec/chips/ttl_74x86.md) |
| Unknown* | 74x87 | 4-bit true/complement/zero/one element | [ttl_74x87](ttl_74xx/spec/chips/ttl_74x87.md) |
| Unknown* | 74x88 | 256-bit ROM (32x8) | [ttl_74x88](ttl_74xx/spec/chips/ttl_74x88.md) |
| Unknown* | 74x89 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | [ttl_74x89](ttl_74xx/spec/chips/ttl_74x89.md) |
| Unknown* | 74x90 | decade counter (separate divide-by-2 and divide-by-5 sections) | [ttl_74x90](ttl_74xx/spec/chips/ttl_74x90.md) |
| Unknown* | 74x91 | 8-bit shift register, serial in, serial out, gated input | [ttl_74x91](ttl_74xx/spec/chips/ttl_74x91.md) |
| Unknown* | 74x92 | divide-by-12 counter (separate divide-by-2 and divide-by-6 sections) | [ttl_74x92](ttl_74xx/spec/chips/ttl_74x92.md) |
| Unknown* | 74x93 | 4-bit binary counter (separate divide-by-2 and divide-by-8 sections); different pinout for 74L93 | [ttl_74x93](ttl_74xx/spec/chips/ttl_74x93.md) |
| Unknown* | 74x94 | 4-bit shift register, dual asynchronous presets | [ttl_74x94](ttl_74xx/spec/chips/ttl_74x94.md) |
| Unknown* | 74x95 | 4-bit shift register, parallel in, parallel out, serial input; different pinout for 74L95 | [ttl_74x95](ttl_74xx/spec/chips/ttl_74x95.md) |
| Unknown* | 74x96 | 5-bit parallel-in/parallel-out shift register, asynchronous preset | [ttl_74x96](ttl_74xx/spec/chips/ttl_74x96.md) |
| Unknown* | 74x97 | synchronous 6-bit binary rate multiplier | [ttl_74x97](ttl_74xx/spec/chips/ttl_74x97.md) |
| Unknown* | 74x98 | 4-bit data selector/storage register | [ttl_74x98](ttl_74xx/spec/chips/ttl_74x98.md) |
| Unknown* | 74x99 | 4-bit bidirectional universal shift register | [ttl_74x99](ttl_74xx/spec/chips/ttl_74x99.md) |
| Unknown* | 74x100 | dual 4-bit bistable latch | [ttl_74x100](ttl_74xx/spec/chips/ttl_74x100.md) |
| Unknown* | 74x101 | AND-OR-gated J-K negative-edge-triggered flip-flop, preset | [ttl_74x101](ttl_74xx/spec/chips/ttl_74x101.md) |
| Unknown* | 74x102 | AND-gated J-K negative-edge-triggered flip-flop, preset and clear | [ttl_74x102](ttl_74xx/spec/chips/ttl_74x102.md) |
| Unknown* | 74x103 | dual J-K negative-edge-triggered flip-flop, clear | [ttl_74x103](ttl_74xx/spec/chips/ttl_74x103.md) |
| Unknown* | 74x104 | J-K master-slave flip-flop | [ttl_74x104](ttl_74xx/spec/chips/ttl_74x104.md) |
| Unknown* | 74x105 | J-K master-slave flip-flop, J2 and K2 inverted | [ttl_74x105](ttl_74xx/spec/chips/ttl_74x105.md) |
| Unknown* | 74x106 | dual J-K negative-edge-triggered flip-flop, preset and clear | [ttl_74x106](ttl_74xx/spec/chips/ttl_74x106.md) |
| Unknown* | 74x107 | dual J-K flip-flop, clear | [ttl_74x107](ttl_74xx/spec/chips/ttl_74x107.md) |
| Unknown* | 74x108 | dual J-K negative-edge-triggered flip-flop, preset, shared clock and clear | [ttl_74x108](ttl_74xx/spec/chips/ttl_74x108.md) |
| Unknown* | 74x109 | dual J-NotK positive-edge-triggered flip-flop, clear and preset | [ttl_74x109](ttl_74xx/spec/chips/ttl_74x109.md) |
| Unknown* | 74x110 | AND-gated J-K master-slave flip-flop, data lockout | [ttl_74x110](ttl_74xx/spec/chips/ttl_74x110.md) |
| Unknown* | 74x111 | dual J-K master-slave flip-flop, data lockout, reset, set | [ttl_74x111](ttl_74xx/spec/chips/ttl_74x111.md) |
| Unknown* | 74x112 | dual J-K negative-edge-triggered flip-flop, clear & preset, Q & /Q outputs | [ttl_74x112](ttl_74xx/spec/chips/ttl_74x112.md) |
| Unknown* | 74x113 | dual J-K negative-edge-triggered flip-flop, preset | [ttl_74x113](ttl_74xx/spec/chips/ttl_74x113.md) |
| Unknown* | 74x114 | dual J-K negative-edge-triggered flip-flop, preset, shared clock and clear | [ttl_74x114](ttl_74xx/spec/chips/ttl_74x114.md) |
| Unknown* | 74x115 | dual J-K master-slave flip-flop, data lockout, reset | [ttl_74x115](ttl_74xx/spec/chips/ttl_74x115.md) |
| Unknown* | 74116 | dual 4-bit latch, clear | [ttl_74116](ttl_74xx/spec/chips/ttl_74116.md) |
| Unknown* | 74H116 | AND-gated J-K flip flop | [ttl_74h116](ttl_74xx/spec/chips/ttl_74h116.md) |
| Unknown* | 74x117 | AND-gated J-K flip flop, one J and K input inverted | [ttl_74x117](ttl_74xx/spec/chips/ttl_74x117.md) |
| Unknown* | 74x118 | hex set/reset latch, shared reset | [ttl_74x118](ttl_74xx/spec/chips/ttl_74x118.md) |
| Unknown* | 74119 | hex set/reset latch | [ttl_74119](ttl_74xx/spec/chips/ttl_74119.md) |
| Unknown* | 74H119 | dual J-K flip-flop, shared clock and clear | [ttl_74h119](ttl_74xx/spec/chips/ttl_74h119.md) |
| Unknown* | 74120 | dual pulse synchronizer/drivers | [ttl_74120](ttl_74xx/spec/chips/ttl_74120.md) |
| Unknown* | 74H120 | dual J-K flip-flop, separate clock inputs | [ttl_74h120](ttl_74xx/spec/chips/ttl_74h120.md) |
| Unknown* | 74x125 | quad bus buffer, negative enable | [ttl_74x125](ttl_74xx/spec/chips/ttl_74x125.md) |
| Unknown* | 74x126 | quad bus buffer, positive enable | [ttl_74x126](ttl_74xx/spec/chips/ttl_74x126.md) |
| Unknown* | 74x128 | quad 2-input NOR gate | [ttl_74x128](ttl_74xx/spec/chips/ttl_74x128.md) |
| Unknown* | 74131 | quad 2-input AND gate | [ttl_74131](ttl_74xx/spec/chips/ttl_74131.md) |
| Unknown* | 74x132 | quad 2-input NAND gate | [ttl_74x132](ttl_74xx/spec/chips/ttl_74x132.md) |
| Unknown* | 74x133 | single 13-input NAND gate | [ttl_74x133](ttl_74xx/spec/chips/ttl_74x133.md) |
| Unknown* | 74x134 | single 12-input NAND gate | [ttl_74x134](ttl_74xx/spec/chips/ttl_74x134.md) |
| Unknown* | 74x135 | quad XOR/XNOR gate, two inputs to select logic type | [ttl_74x135](ttl_74xx/spec/chips/ttl_74x135.md) |
| Unknown* | 74x136 | quad 2-input XOR gate | [ttl_74x136](ttl_74xx/spec/chips/ttl_74x136.md) |
| Unknown* | 74x137 | 3-to-8 line decoder/demultiplexer, address latch, inverting outputs | [ttl_74x137](ttl_74xx/spec/chips/ttl_74x137.md) |
| Unknown* | 74x138 | 3-to-8 line decoder/demultiplexer, inverting outputs | [ttl_74x138](ttl_74xx/spec/chips/ttl_74x138.md) |
| Unknown* | 74x139 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | [ttl_74x139](ttl_74xx/spec/chips/ttl_74x139.md) |
| Unknown* | 74x140 | dual 4-input NAND gate | [ttl_74x140](ttl_74xx/spec/chips/ttl_74x140.md) |
| Unknown* | 74x141 | BCD to decimal decoder/driver for cold-cathode indicator / Nixie tube | [ttl_74x141](ttl_74xx/spec/chips/ttl_74x141.md) |
| Unknown* | 74x142 | decade counter/latch/decoder/driver for Nixie tubes | [ttl_74x142](ttl_74xx/spec/chips/ttl_74x142.md) |
| Unknown* | 74x143 | decade counter/latch/decoder/7-segment driver | [ttl_74x143](ttl_74xx/spec/chips/ttl_74x143.md) |
| Unknown* | 74x144 | decade counter/latch/decoder/7-segment driver | [ttl_74x144](ttl_74xx/spec/chips/ttl_74x144.md) |
| Unknown* | 74x145 | BCD to decimal decoder/driver | [ttl_74x145](ttl_74xx/spec/chips/ttl_74x145.md) |
| Unknown* | 74x146 | 3-to-8 line decoder | [ttl_74x146](ttl_74xx/spec/chips/ttl_74x146.md) |
| Unknown* | 74x147 | 10-line to 4-line priority encoder | [ttl_74x147](ttl_74xx/spec/chips/ttl_74x147.md) |
| Unknown* | 74x148 | 8-line to 3-line priority encoder | [ttl_74x148](ttl_74xx/spec/chips/ttl_74x148.md) |
| Unknown* | 74x149 | 8-line to 8-line priority encoder | [ttl_74x149](ttl_74xx/spec/chips/ttl_74x149.md) |
| Unknown* | 74x150 | 16-line to 1-line data selector/multiplexer | [ttl_74x150](ttl_74xx/spec/chips/ttl_74x150.md) |
| Unknown* | 74x151 | 8-line to 1-line data selector/multiplexer | [ttl_74x151](ttl_74xx/spec/chips/ttl_74x151.md) |
| Unknown* | 74x152 | 8-line to 1-line data selector/multiplexer, inverting output | [ttl_74x152](ttl_74xx/spec/chips/ttl_74x152.md) |
| Unknown* | 74x153 | dual 4-line to 1-line data selector/multiplexer, non-inverting outputs | [ttl_74x153](ttl_74xx/spec/chips/ttl_74x153.md) |
| Unknown* | 74x154 | 4-to-16 line decoder/demultiplexer, inverting outputs | [ttl_74x154](ttl_74xx/spec/chips/ttl_74x154.md) |
| Unknown* | 74x155 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | [ttl_74x155](ttl_74xx/spec/chips/ttl_74x155.md) |
| Unknown* | 74x156 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | [ttl_74x156](ttl_74xx/spec/chips/ttl_74x156.md) |
| Unknown* | 74x157 | quad 2-line to 1-line data selector/multiplexer, non-inverting outputs | [ttl_74x157](ttl_74xx/spec/chips/ttl_74x157.md) |
| Unknown* | 74x158 | quad 2-line to 1-line data selector/multiplexer, inverting outputs | [ttl_74x158](ttl_74xx/spec/chips/ttl_74x158.md) |
| Unknown* | 74x159 | 4-to-16 line decoder/demultiplexer | [ttl_74x159](ttl_74xx/spec/chips/ttl_74x159.md) |
| Unknown* | 74x160 | synchronous presettable 4-bit decade counter, asynchronous clear | [ttl_74x160](ttl_74xx/spec/chips/ttl_74x160.md) |
| Unknown* | 74x161 | synchronous presettable 4-bit binary counter, asynchronous clear | [ttl_74x161](ttl_74xx/spec/chips/ttl_74x161.md) |
| Unknown* | 74x162 | synchronous presettable 4-bit decade counter, synchronous clear | [ttl_74x162](ttl_74xx/spec/chips/ttl_74x162.md) |
| Unknown* | 74x163 | synchronous presettable 4-bit binary counter, synchronous clear | [ttl_74x163](ttl_74xx/spec/chips/ttl_74x163.md) |
| Unknown* | 74x164 | 8-bit serial-in parallel-out (SIPO) shift register, asynchronous clear, not output latch | [ttl_74x164](ttl_74xx/spec/chips/ttl_74x164.md) |
| Unknown* | 74x165 | 8-bit parallel-in serial-out (PISO) shift register, parallel load, complementary outputs | [ttl_74x165](ttl_74xx/spec/chips/ttl_74x165.md) |
| Unknown* | 74x166 | parallel-load 8-bit shift register | [ttl_74x166](ttl_74xx/spec/chips/ttl_74x166.md) |
| Unknown* | 74x167 | synchronous decade rate multiplier | [ttl_74x167](ttl_74xx/spec/chips/ttl_74x167.md) |
| Unknown* | 74x168 | synchronous presettable 4-bit up/down decade counter | [ttl_74x168](ttl_74xx/spec/chips/ttl_74x168.md) |
| Unknown* | 74x169 | synchronous presettable 4-bit up/down binary counter | [ttl_74x169](ttl_74xx/spec/chips/ttl_74x169.md) |
| Unknown* | 74x170 | 16-bit register file (4x4) | [ttl_74x170](ttl_74xx/spec/chips/ttl_74x170.md) |
| Unknown* | 74x171 | quad D flip-flops, shared clock and clear | [ttl_74x171](ttl_74xx/spec/chips/ttl_74x171.md) |
| Unknown* | 74x172 | 16-bit multiple port register file (8x2) | [ttl_74x172](ttl_74xx/spec/chips/ttl_74x172.md) |
| Unknown* | 74x173 | quad D flip-flop, shared clock and asynchronous clear and enable, Q & /Q outputs | [ttl_74x173](ttl_74xx/spec/chips/ttl_74x173.md) |
| Unknown* | 74x174 | hex D flip-flop, shared clock and asynchronous clear, Q outputs | [ttl_74x174](ttl_74xx/spec/chips/ttl_74x174.md) |
| Unknown* | 74x175 | quad D edge-triggered flip-flop, shared clock and asynchronous clear, Q & /Q outputs | [ttl_74x175](ttl_74xx/spec/chips/ttl_74x175.md) |
| Unknown* | 74x176 | presettable decade (bi-quinary) counter/latch | [ttl_74x176](ttl_74xx/spec/chips/ttl_74x176.md) |
| Unknown* | 74x177 | presettable binary counter/latch | [ttl_74x177](ttl_74xx/spec/chips/ttl_74x177.md) |
| Unknown* | 74x178 | 4-bit parallel-access shift register | [ttl_74x178](ttl_74xx/spec/chips/ttl_74x178.md) |
| Unknown* | 74x179 | 4-bit parallel-access shift register, asynchronous clear input, complementary Q output | [ttl_74x179](ttl_74xx/spec/chips/ttl_74x179.md) |
| Unknown* | 74x180 | 9-bit odd/even parity bit generator and checker | [ttl_74x180](ttl_74xx/spec/chips/ttl_74x180.md) |
| Unknown* | 74x182 | lookahead carry generator | [ttl_74x182](ttl_74xx/spec/chips/ttl_74x182.md) |
| Unknown* | 74x183 | dual carry-save full adder | [ttl_74x183](ttl_74xx/spec/chips/ttl_74x183.md) |
| Unknown* | 74x184 | BCD to binary converter | [ttl_74x184](ttl_74xx/spec/chips/ttl_74x184.md) |
| Unknown* | 74x185 | 6-bit binary to BCD converter | [ttl_74x185](ttl_74xx/spec/chips/ttl_74x185.md) |
| Unknown* | 74x186 | 512-bit ROM (64x8) | [ttl_74x186](ttl_74xx/spec/chips/ttl_74x186.md) |
| Unknown* | 74x187 | 1024-bit ROM (256x4) | [ttl_74x187](ttl_74xx/spec/chips/ttl_74x187.md) |
| Unknown* | 74x188 | 256-bit PROM (32x8) | [ttl_74x188](ttl_74xx/spec/chips/ttl_74x188.md) |
| Unknown* | 74x189 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | [ttl_74x189](ttl_74xx/spec/chips/ttl_74x189.md) |
| Unknown* | 74x190 | synchronous presettable up/down 4-bit decade counter | [ttl_74x190](ttl_74xx/spec/chips/ttl_74x190.md) |
| Unknown* | 74x191 | synchronous presettable up/down 4-bit binary counter | [ttl_74x191](ttl_74xx/spec/chips/ttl_74x191.md) |
| Unknown* | 74x192 | synchronous presettable up/down 4-bit decade counter, clear | [ttl_74x192](ttl_74xx/spec/chips/ttl_74x192.md) |
| Unknown* | 74x193 | synchronous presettable up/down 4-bit binary counter, clear | [ttl_74x193](ttl_74xx/spec/chips/ttl_74x193.md) |
| Unknown* | 74x194 | 4-bit bidirectional universal shift register | [ttl_74x194](ttl_74xx/spec/chips/ttl_74x194.md) |
| Unknown* | 74x195 | 4-bit parallel-access shift register | [ttl_74x195](ttl_74xx/spec/chips/ttl_74x195.md) |
| Unknown* | 74x196 | presettable 4-bit decade counter/latch | [ttl_74x196](ttl_74xx/spec/chips/ttl_74x196.md) |
| Unknown* | 74x197 | presettable 4-bit binary counter/latch | [ttl_74x197](ttl_74xx/spec/chips/ttl_74x197.md) |
| Unknown* | 74x198 | 8-bit bidirectional universal shift register | [ttl_74x198](ttl_74xx/spec/chips/ttl_74x198.md) |
| Unknown* | 74x199 | 8-bit universal shift register, J-NotK serial inputs | [ttl_74x199](ttl_74xx/spec/chips/ttl_74x199.md) |
| Unknown* | 74x200 | 256-bit RAM (256x1) | [ttl_74x200](ttl_74xx/spec/chips/ttl_74x200.md) |
| Unknown* | 74x201 | 256-bit RAM (256x1) | [ttl_74x201](ttl_74xx/spec/chips/ttl_74x201.md) |
| Unknown* | 74x202 | 256-bit RAM (256x1) with power down | [ttl_74x202](ttl_74xx/spec/chips/ttl_74x202.md) |
| Unknown* | 74x206 | 256-bit RAM (256x1) | [ttl_74x206](ttl_74xx/spec/chips/ttl_74x206.md) |
| Unknown* | 74x207 | 1024-bit RAM (256x4) | [ttl_74x207](ttl_74xx/spec/chips/ttl_74x207.md) |
| Unknown* | 74x208 | 1024-bit RAM (256x4), separate data in- and outputs | [ttl_74x208](ttl_74xx/spec/chips/ttl_74x208.md) |
| Unknown* | 74x209 | 1024-bit RAM (1024x1) | [ttl_74x209](ttl_74xx/spec/chips/ttl_74x209.md) |
| Unknown* | 74x210 | octal buffer, inverting | [ttl_74x210](ttl_74xx/spec/chips/ttl_74x210.md) |
| Unknown* | 74x211 | 144-bit RAM (16x9) with output latch | [ttl_74x211](ttl_74xx/spec/chips/ttl_74x211.md) |
| Unknown* | 74x212 | 144-bit RAM (16x9) | [ttl_74x212](ttl_74xx/spec/chips/ttl_74x212.md) |
| Unknown* | 74x213 | 192-bit RAM (16x12) | [ttl_74x213](ttl_74xx/spec/chips/ttl_74x213.md) |
| Unknown* | 74x214 | 1024-bit RAM (1024x1) | [ttl_74x214](ttl_74xx/spec/chips/ttl_74x214.md) |
| Unknown* | 74x215 | 1024-bit RAM (1024x1) with power-down mode | [ttl_74x215](ttl_74xx/spec/chips/ttl_74x215.md) |
| Unknown* | 74x216 | 256-bit RAM (64x4), common I/O | [ttl_74x216](ttl_74xx/spec/chips/ttl_74x216.md) |
| Unknown* | 74x217 | 256-bit RAM (64x4) | [ttl_74x217](ttl_74xx/spec/chips/ttl_74x217.md) |
| Unknown* | 74x218 | 256-bit RAM (32x8) | [ttl_74x218](ttl_74xx/spec/chips/ttl_74x218.md) |
| Unknown* | 74x219 | 64-bit RAM (16x4), non-inverting outputs | [ttl_74x219](ttl_74xx/spec/chips/ttl_74x219.md) |
| Unknown* | 74x222 | 64-bit FIFO memory (16x4), synchronous, input/output ready enable | [ttl_74x222](ttl_74xx/spec/chips/ttl_74x222.md) |
| Unknown* | 74x224 | 64-bit FIFO memory (16x4), synchronous | [ttl_74x224](ttl_74xx/spec/chips/ttl_74x224.md) |
| Unknown* | 74x225 | 80-bit FIFO memory (16x5), asynchronous | [ttl_74x225](ttl_74xx/spec/chips/ttl_74x225.md) |
| Unknown* | 74x226 | 4-bit parallel latched bus transceiver | [ttl_74x226](ttl_74xx/spec/chips/ttl_74x226.md) |
| Unknown* | 74x227 | 64-bit FIFO memory (16x4), synchronous, input/output ready enable | [ttl_74x227](ttl_74xx/spec/chips/ttl_74x227.md) |
| Unknown* | 74x228 | 64-bit FIFO memory (16x4), synchronous | [ttl_74x228](ttl_74xx/spec/chips/ttl_74x228.md) |
| Unknown* | 74x229 | 80-bit FIFO memory (16x5), asynchronous | [ttl_74x229](ttl_74xx/spec/chips/ttl_74x229.md) |
| Unknown* | 74x230 | dual 4-bit buffer/driver, one inverted, one non-inverted; negative enable | [ttl_74x230](ttl_74xx/spec/chips/ttl_74x230.md) |
| Unknown* | 74x231 | dual 4-bit buffer/driver, both inverted; one positive and one negative enable | [ttl_74x231](ttl_74xx/spec/chips/ttl_74x231.md) |
| Unknown* | 74x232 | 64-bit FIFO memory (16x4), asynchronous | [ttl_74x232](ttl_74xx/spec/chips/ttl_74x232.md) |
| Unknown* | 74x233 | 80-bit FIFO memory (16x5), asynchronous | [ttl_74x233](ttl_74xx/spec/chips/ttl_74x233.md) |
| Unknown* | 74x234 | 256-bit FIFO memory (64x4), asynchronous | [ttl_74x234](ttl_74xx/spec/chips/ttl_74x234.md) |
| Unknown* | 74x235 | 320-bit FIFO memory (64x5), asynchronous | [ttl_74x235](ttl_74xx/spec/chips/ttl_74x235.md) |
| Unknown* | 74x236 | 256-bit FIFO memory (64x4), asynchronous | [ttl_74x236](ttl_74xx/spec/chips/ttl_74x236.md) |
| Unknown* | 74x237 | 3-to-8 line decoder/demultiplexer, address latch, active high outputs | [ttl_74x237](ttl_74xx/spec/chips/ttl_74x237.md) |
| Unknown* | 74x238 | 3-to-8 line decoder/demultiplexer, active high outputs | [ttl_74x238](ttl_74xx/spec/chips/ttl_74x238.md) |
| Unknown* | 74x239 | dual 2-to-4 line decoder/demultiplexer, active high outputs | [ttl_74x239](ttl_74xx/spec/chips/ttl_74x239.md) |
| Unknown* | 74x240 | octal buffer, inverting outputs | [ttl_74x240](ttl_74xx/spec/chips/ttl_74x240.md) |
| Unknown* | 74x241 | octal buffer, non-inverting outputs | [ttl_74x241](ttl_74xx/spec/chips/ttl_74x241.md) |
| Unknown* | 74x242 | quad bus transceiver, inverting outputs | [ttl_74x242](ttl_74xx/spec/chips/ttl_74x242.md) |
| Unknown* | 74x243 | quad bus transceiver, non-inverting outputs | [ttl_74x243](ttl_74xx/spec/chips/ttl_74x243.md) |
| Unknown* | 74x244 | octal buffer, non-inverting outputs | [ttl_74x244](ttl_74xx/spec/chips/ttl_74x244.md) |
| Unknown* | 74x245 | octal bus transceiver, non-inverting outputs | [ttl_74x245](ttl_74xx/spec/chips/ttl_74x245.md) |
| Unknown* | 74x246 | BCD to 7-segment decoder/driver | [ttl_74x246](ttl_74xx/spec/chips/ttl_74x246.md) |
| Unknown* | 74x247 | BCD to 7-segment decoder/driver | [ttl_74x247](ttl_74xx/spec/chips/ttl_74x247.md) |
| Unknown* | 74x248 | BCD to 7-segment decoder/driver | [ttl_74x248](ttl_74xx/spec/chips/ttl_74x248.md) |
| Unknown* | 74x249 | BCD to 7-segment decoder/driver | [ttl_74x249](ttl_74xx/spec/chips/ttl_74x249.md) |
| Unknown* | 74x250 | 1 of 16 data selector/multiplexer | [ttl_74x250](ttl_74xx/spec/chips/ttl_74x250.md) |
| Unknown* | 74x251 | 8-line to 1-line data selector/multiplexer, complementary outputs | [ttl_74x251](ttl_74xx/spec/chips/ttl_74x251.md) |
| Unknown* | 74x253 | dual 4-line to 1-line data selector/multiplexer | [ttl_74x253](ttl_74xx/spec/chips/ttl_74x253.md) |
| Unknown* | 74x255 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | [ttl_74x255](ttl_74xx/spec/chips/ttl_74x255.md) |
| Unknown* | 74x256 | dual 4-bit addressable latch | [ttl_74x256](ttl_74xx/spec/chips/ttl_74x256.md) |
| Unknown* | 74x257 | quad 2-line to 1-line data selector/multiplexer, non-inverting outputs | [ttl_74x257](ttl_74xx/spec/chips/ttl_74x257.md) |
| Unknown* | 74x258 | quad 2-line to 1-line data selector/multiplexer, inverting outputs | [ttl_74x258](ttl_74xx/spec/chips/ttl_74x258.md) |
| Unknown* | 74x259 | 8-bit bit addressable input latch with clr | [ttl_74x259](ttl_74xx/spec/chips/ttl_74x259.md) |
| Unknown* | 74x260 | dual 5-input NOR gate | [ttl_74x260](ttl_74xx/spec/chips/ttl_74x260.md) |
| Unknown* | 74x261 | 2-bit by 4-bit parallel binary multiplier | [ttl_74x261](ttl_74xx/spec/chips/ttl_74x261.md) |
| Unknown* | 74x262 | 5760-bit read-only character memory (128 by 45-bit bitmaps) | [ttl_74x262](ttl_74xx/spec/chips/ttl_74x262.md) |
| Unknown* | 74x264 | look ahead carry generator | [ttl_74x264](ttl_74xx/spec/chips/ttl_74x264.md) |
| Unknown* | 74x265 | quad complementary output elements | [ttl_74x265](ttl_74xx/spec/chips/ttl_74x265.md) |
| Unknown* | 74x266 | quad 2-input XNOR gate | [ttl_74x266](ttl_74xx/spec/chips/ttl_74x266.md) |
| Unknown* | 74x268 | hex D-type latches, shared enable and output control | [ttl_74x268](ttl_74xx/spec/chips/ttl_74x268.md) |
| Unknown* | 74x269 | 8-bit bidirectional binary counter | [ttl_74x269](ttl_74xx/spec/chips/ttl_74x269.md) |
| Unknown* | 74x270 | 2048-bit ROM (512x4) | [ttl_74x270](ttl_74xx/spec/chips/ttl_74x270.md) |
| Unknown* | 74x271 | 2048-bit ROM (256x8) | [ttl_74x271](ttl_74xx/spec/chips/ttl_74x271.md) |
| Unknown* | 74x273 | 8-bit register, asynchronous clear | [ttl_74x273](ttl_74xx/spec/chips/ttl_74x273.md) |
| Unknown* | 74x274 | 4-bit by 4-bit binary multiplier | [ttl_74x274](ttl_74xx/spec/chips/ttl_74x274.md) |
| Unknown* | 74x275 | 7-bit slice Wallace tree | [ttl_74x275](ttl_74xx/spec/chips/ttl_74x275.md) |
| Unknown* | 74x276 | quad J-NotK edge-triggered flip-flops, separate clocks, shared preset and clear | [ttl_74x276](ttl_74xx/spec/chips/ttl_74x276.md) |
| Unknown* | 74x278 | 4-bit cascadeable priority registers, latched data inputs | [ttl_74x278](ttl_74xx/spec/chips/ttl_74x278.md) |
| Unknown* | 74x279 | quad set-reset latch | [ttl_74x279](ttl_74xx/spec/chips/ttl_74x279.md) |
| Unknown* | 74x280 | 9-bit odd/even parity bit generator/checker | [ttl_74x280](ttl_74xx/spec/chips/ttl_74x280.md) |
| Unknown* | 74x281 | 4-bit parallel binary accumulator | [ttl_74x281](ttl_74xx/spec/chips/ttl_74x281.md) |
| Unknown* | 74x282 | look-ahead carry generator, selectable carry inputs | [ttl_74x282](ttl_74xx/spec/chips/ttl_74x282.md) |
| Unknown* | 74x283 | 4-bit binary full adder (has carry in function) | [ttl_74x283](ttl_74xx/spec/chips/ttl_74x283.md) |
| Unknown* | 74x284 | 4-bit by 4-bit parallel binary multiplier (high order 4 bits of product) | [ttl_74x284](ttl_74xx/spec/chips/ttl_74x284.md) |
| Unknown* | 74x285 | 4-bit by 4-bit parallel binary multiplier (low order 4 bits of product) | [ttl_74x285](ttl_74xx/spec/chips/ttl_74x285.md) |
| Unknown* | 74x286 | 9-bit parity generator/checker, bus driver parity I/O port | [ttl_74x286](ttl_74xx/spec/chips/ttl_74x286.md) |
| Unknown* | 74x287 | 1024-bit PROM (256x4) | [ttl_74x287](ttl_74xx/spec/chips/ttl_74x287.md) |
| Unknown* | 74x288 | 256-bit PROM (32x8) | [ttl_74x288](ttl_74xx/spec/chips/ttl_74x288.md) |
| Unknown* | 74x289 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | [ttl_74x289](ttl_74xx/spec/chips/ttl_74x289.md) |
| Unknown* | 74x290 | decade counter (separate divide-by-2 and divide-by-5 sections) | [ttl_74x290](ttl_74xx/spec/chips/ttl_74x290.md) |
| Unknown* | 74x292 | programmable frequency divider/digital timer | [ttl_74x292](ttl_74xx/spec/chips/ttl_74x292.md) |
| Unknown* | 74x293 | 4-bit binary counter (separate divide-by-2 and divide-by-8 sections) | [ttl_74x293](ttl_74xx/spec/chips/ttl_74x293.md) |
| Unknown* | 74x294 | programmable frequency divider/digital timer | [ttl_74x294](ttl_74xx/spec/chips/ttl_74x294.md) |
| Unknown* | 74x295 | 4-bit bidirectional shift register | [ttl_74x295](ttl_74xx/spec/chips/ttl_74x295.md) |
| Unknown* | 74x297 | digital phase-locked loop filter | [ttl_74x297](ttl_74xx/spec/chips/ttl_74x297.md) |
| Unknown* | 74x298 | quad 2-input multiplexer, storage | [ttl_74x298](ttl_74xx/spec/chips/ttl_74x298.md) |
| Unknown* | 74x299 | 8-bit bidirectional universal shift/storage register | [ttl_74x299](ttl_74xx/spec/chips/ttl_74x299.md) |

## Extended numbered 74-series catalog

All entries are in the shared [ttl_74xx](ttl_74xx/) folder. These additional
entries preserve unknown first-introduced years explicitly; each specification
links its manufacturer source and implementation status.

| Year | Chip | Function | Design / status |
|---|---|---|---|
| Unknown | 74x300 | 256-bit RAM (256x1) | [implemented](ttl_74xx/spec/chips/ttl_74x300.md) |
| Unknown | 74x301 | 256-bit RAM (256x1) | [implemented](ttl_74xx/spec/chips/ttl_74x301.md) |
| Unknown | 74x302 | 256-bit RAM (256x1) | [implemented](ttl_74xx/spec/chips/ttl_74x302.md) |
| Unknown | 74x303 | octal divide-by-2 clock driver, 2 outputs inverted | [implemented](ttl_74xx/spec/chips/ttl_74x303.md) |
| Unknown | 74x304 | octal divide-by-2 clock driver | [implemented](ttl_74xx/spec/chips/ttl_74x304.md) |
| Unknown | 74x305 | octal divide-by-2 clock driver, 4 outputs inverted | [implemented](ttl_74xx/spec/chips/ttl_74x305.md) |
| Unknown | 74x306 | 8-bit LV-TTL to GTL+ bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x306.md) |
| Unknown | 74x309 | 1024-bit RAM (1024x1) | [implemented](ttl_74xx/spec/chips/ttl_74x309.md) |
| Unknown | 74x310 | octal buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x310.md) |
| Unknown | 74x311 | 144-bit RAM (16x9) with output latch | [implemented](ttl_74xx/spec/chips/ttl_74x311.md) |
| Unknown | 74x312 | 144-bit RAM (16x9) | [implemented](ttl_74xx/spec/chips/ttl_74x312.md) |
| Unknown | 74x313 | 192-bit RAM (16x12) | [implemented](ttl_74xx/spec/chips/ttl_74x313.md) |
| Unknown | 74x314 | 1024-bit RAM (1024x1) | [implemented](ttl_74xx/spec/chips/ttl_74x314.md) |
| Unknown | 74x315 | 1024-bit RAM (1024x1) with power-down mode | [implemented](ttl_74xx/spec/chips/ttl_74x315.md) |
| Unknown | 74x316 | 256-bit RAM (64x4), common I/O | [implemented](ttl_74xx/spec/chips/ttl_74x316.md) |
| Unknown | 74x317 | 256-bit RAM (64x4) | [implemented](ttl_74xx/spec/chips/ttl_74x317.md) |
| Unknown | 74x318 | 256-bit RAM (32x8) | [implemented](ttl_74xx/spec/chips/ttl_74x318.md) |
| Unknown | 74x319 | 64-bit RAM (16x4) | [implemented](ttl_74xx/spec/chips/ttl_74x319.md) |
| Unknown | 74x320 | crystal-controlled oscillator | [excluded](ttl_74xx/spec/chips/ttl_74x320.md) |
| Unknown | 74x321 | crystal-controlled oscillators, F/2 and F/4 count-down outputs | [excluded](ttl_74xx/spec/chips/ttl_74x321.md) |
| Unknown | 74x322 | 8-bit shift register, sign extend | [implemented](ttl_74xx/spec/chips/ttl_74x322.md) |
| Unknown | 74x323 | 8-bit bidirectional universal shift/storage register, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x323.md) |
| Unknown | 74x324 | voltage-controlled oscillator (or crystal controlled), enable input, complementary outputs | [excluded](ttl_74xx/spec/chips/ttl_74x324.md) |
| Unknown | 74x325 | dual voltage-controlled oscillator (or crystal controlled), complementary outputs | [excluded](ttl_74xx/spec/chips/ttl_74x325.md) |
| Unknown | 74x326 | dual voltage-controlled oscillator (or crystal controlled), enable input, complementary outputs | [excluded](ttl_74xx/spec/chips/ttl_74x326.md) |
| Unknown | 74x327 | dual voltage-controlled oscillator (or crystal controlled) | [excluded](ttl_74xx/spec/chips/ttl_74x327.md) |
| Unknown | 74x330 | PLA (12 inputs, 50 terms, 6 outputs) | [implemented](ttl_74xx/spec/chips/ttl_74x330.md) |
| Unknown | 74x331 | PLA (12 inputs, 50 terms, 6 outputs) | [implemented](ttl_74xx/spec/chips/ttl_74x331.md) |
| Unknown | 74x333 | PLA (12 inputs, 32 terms, 6 outputs, 4 state registers) | [implemented](ttl_74xx/spec/chips/ttl_74x333.md) |
| Unknown | 74x334 | PLA (12 inputs, 32 terms, 6 outputs) | [implemented](ttl_74xx/spec/chips/ttl_74x334.md) |
| Unknown | 74x335 | PLA (12 inputs, 32 terms, 6 outputs, 4 state registers) | [implemented](ttl_74xx/spec/chips/ttl_74x335.md) |
| Unknown | 74x336 | PLA (12 inputs, 32 terms, 6 outputs) | [implemented](ttl_74xx/spec/chips/ttl_74x336.md) |
| Unknown | 74x337 | clock driver | [implemented](ttl_74xx/spec/chips/ttl_74x337.md) |
| Unknown | 74x340 | octal buffer, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x340.md) |
| Unknown | 74x341 | octal buffer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x341.md) |
| Unknown | 74x344 | octal buffer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x344.md) |
| Unknown | 74x347 | BCD to 7-segment decoders/drivers, low voltage version of 7447 | [implemented](ttl_74xx/spec/chips/ttl_74x347.md) |
| Unknown | 74x348 | 8 to 3-line priority encoder | [implemented](ttl_74xx/spec/chips/ttl_74x348.md) |
| Unknown | 74x350 | 4-bit shifter | [implemented](ttl_74xx/spec/chips/ttl_74x350.md) |
| Unknown | 74x351 | dual 8-line to 1-line data selectors/multiplexers, 4 common data inputs | [implemented](ttl_74xx/spec/chips/ttl_74x351.md) |
| Unknown | 74x352 | dual 4-line to 1-line data selectors/multiplexers, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x352.md) |
| Unknown | 74x353 | dual 4-line to 1-line data selectors/multiplexers, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x353.md) |
| Unknown | 74x354 | 8-line to 1-line data selector/multiplexer, transparent registers | [implemented](ttl_74xx/spec/chips/ttl_74x354.md) |
| Unknown | 74x355 | 8-line to 1-line data selector/multiplexer, transparent registers | [implemented](ttl_74xx/spec/chips/ttl_74x355.md) |
| Unknown | 74x356 | 8-line to 1-line data selector/multiplexer, edge-triggered registers | [implemented](ttl_74xx/spec/chips/ttl_74x356.md) |
| Unknown | 74x357 | 8-line to 1-line data selector/multiplexer, edge-triggered registers | [implemented](ttl_74xx/spec/chips/ttl_74x357.md) |
| Unknown | 74x361 | bubble memory function timing generator | [pending](ttl_74xx/spec/chips/ttl_74x361.md) |
| Unknown | 74x362 | four-phase clock generator/driver for Texas Instruments TMS9900 | [implemented](ttl_74xx/spec/chips/ttl_74x362.md) |
| Unknown | 74x363 | octal transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x363.md) |
| Unknown | 74x364 | octal edge-triggered D-type register | [implemented](ttl_74xx/spec/chips/ttl_74x364.md) |
| Unknown | 74x365 | hex buffer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x365.md) |
| Unknown | 74x366 | hex buffer, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x366.md) |
| Unknown | 74x367 | hex buffer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x367.md) |
| Unknown | 74x368 | hex buffer, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x368.md) |
| Unknown | 74x370 | 2048-bit ROM (512x4) | [implemented](ttl_74xx/spec/chips/ttl_74x370.md) |
| Unknown | 74x371 | 2048-bit ROM (256x8) | [implemented](ttl_74xx/spec/chips/ttl_74x371.md) |
| Unknown | 74x373 | octal transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x373.md) |
| Unknown | 74x374 | octal register | [implemented](ttl_74xx/spec/chips/ttl_74x374.md) |
| Unknown | 74x375 | quad bistable latch | [implemented](ttl_74xx/spec/chips/ttl_74x375.md) |
| Unknown | 74x376 | quad J-NotK flip-flop, shared clock and clear | [implemented](ttl_74xx/spec/chips/ttl_74x376.md) |
| Unknown | 74x377 | 8-bit register, clock enable | [implemented](ttl_74xx/spec/chips/ttl_74x377.md) |
| Unknown | 74x378 | 6-bit register, clock enable | [implemented](ttl_74xx/spec/chips/ttl_74x378.md) |
| Unknown | 74x379 | 4-bit register, clock enable and complementary outputs | [implemented](ttl_74xx/spec/chips/ttl_74x379.md) |
| Unknown | 74x380 | 8-bit multifunction register (combines features of x374, x377, x273, x534 ICs) | [implemented](ttl_74xx/spec/chips/ttl_74x380.md) |
| Unknown | 74x381 | 4-bit arithmetic logic unit/function generator, generate and propagate outputs | [implemented](ttl_74xx/spec/chips/ttl_74x381.md) |
| Unknown | 74x382 | 4-bit arithmetic logic unit/function generator, ripple carry and overflow outputs | [implemented](ttl_74xx/spec/chips/ttl_74x382.md) |
| Unknown | 74x383 | 8-bit register | [implemented](ttl_74xx/spec/chips/ttl_74x383.md) |
| Unknown | 74x384 | 8-bit by 1-bit two's complement multipliers | [implemented](ttl_74xx/spec/chips/ttl_74x384.md) |
| Unknown | 74x385 | quad serial adder/subtractor | [implemented](ttl_74xx/spec/chips/ttl_74x385.md) |
| Unknown | 74x386 | quad 2-input XOR gate | [implemented](ttl_74xx/spec/chips/ttl_74x386.md) |
| Unknown | 74x387 | 1024-bit PROM (256x4) | [implemented](ttl_74xx/spec/chips/ttl_74x387.md) |
| Unknown | 74x388 | 4-bit D-type register | [implemented](ttl_74xx/spec/chips/ttl_74x388.md) |
| Unknown | 74x390 | dual 4-bit decade counter, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x390.md) |
| Unknown | 74x393 | dual 4-bit binary counter, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x393.md) |
| Unknown | 74x395 | 4-bit cascadable shift register | [implemented](ttl_74xx/spec/chips/ttl_74x395.md) |
| Unknown | 74x396 | octal storage registers, parallel access | [implemented](ttl_74xx/spec/chips/ttl_74x396.md) |
| Unknown | 74x398 | quad 2-input multiplexers, storage and complementary outputs | [implemented](ttl_74xx/spec/chips/ttl_74x398.md) |
| Unknown | 74x399 | quad 2-input multiplexer, storage | [implemented](ttl_74xx/spec/chips/ttl_74x399.md) |
| Unknown | 74x401 | CRC generator/checker | [implemented](ttl_74xx/spec/chips/ttl_74x401.md) |
| Unknown | 74x402 | serial data polynomial generator/checker | [implemented](ttl_74xx/spec/chips/ttl_74x402.md) |
| Unknown | 74x403 | 64-bit FIFO memory (16x4) | [implemented](ttl_74xx/spec/chips/ttl_74x403.md) |
| Unknown | 74x405 | 3-to-8 line decoder (equivalent to Intel 8205) | [implemented](ttl_74xx/spec/chips/ttl_74x405.md) |
| Unknown | 74406 | 3-to-8 line decoder | [implemented](ttl_74xx/spec/chips/ttl_74406.md) |
| Unknown | 74x407 | data access register | [implemented](ttl_74xx/spec/chips/ttl_74x407.md) |
| Unknown | 74408 | 8-bit parity tree | [implemented](ttl_74xx/spec/chips/ttl_74408.md) |
| Unknown | 74S408 | controller/driver for 16k/64k/256k dRAM | [pending](ttl_74xx/spec/chips/ttl_74s408.md) |
| Unknown | 74x409 | controller/driver for 16k/64k/256k dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x409.md) |
| Unknown | 74x410 | 64-bit RAM (16x4) with output register | [implemented](ttl_74xx/spec/chips/ttl_74x410.md) |
| Unknown | 74x411 | FIFO RAM controller | [implemented](ttl_74xx/spec/chips/ttl_74x411.md) |
| Unknown | 74x412 | multi-mode buffered 8-bit latches (equivalent to Intel 3212/8212) | [implemented](ttl_74xx/spec/chips/ttl_74x412.md) |
| Unknown | 74x413 | 256-bit FIFO memory (64x4) | [implemented](ttl_74xx/spec/chips/ttl_74x413.md) |
| Unknown | 74x414 | interrupt priority controller for Intel 8080 (equivalent to Intel 8214) | [implemented](ttl_74xx/spec/chips/ttl_74x414.md) |
| Unknown | 74416 | modulo 10 counter, preload and clear inputs | [implemented](ttl_74xx/spec/chips/ttl_74416.md) |
| Unknown | 74S416 | 4-bit bidirectional bus transceiver, non-inverting (equivalent to Intel 8216) | [implemented](ttl_74xx/spec/chips/ttl_74s416.md) |
| Unknown | 74x417 | modulo 2 and modulo 5 counters, shared preload and clear inputs | [implemented](ttl_74xx/spec/chips/ttl_74x417.md) |
| Unknown | 74418 | modulo 16 counter, preload and clear inputs | [implemented](ttl_74xx/spec/chips/ttl_74418.md) |
| Unknown | 74419 | dual modulo 4 counters, shared preload and clear inputs | [implemented](ttl_74xx/spec/chips/ttl_74419.md) |
| Unknown | 74S419 | FIFO RAM controller | [implemented](ttl_74xx/spec/chips/ttl_74s419.md) |
| Unknown | 74x420 | 32-bit check bit / syndrome bit generator | [implemented](ttl_74xx/spec/chips/ttl_74x420.md) |
| Unknown | 74x422 | retriggerable monostable multivibrators, two inputs | [excluded](ttl_74xx/spec/chips/ttl_74x422.md) |
| Unknown | 74x423 | dual retriggerable monostable multivibrator | [excluded](ttl_74xx/spec/chips/ttl_74x423.md) |
| Unknown | 74424 | dual voltage-controlled oscillator | [excluded](ttl_74xx/spec/chips/ttl_74424.md) |
| Unknown | 74LS424 | two-phase clock generator/driver for Intel 8080 (equivalent to Intel 8224) | [implemented](ttl_74xx/spec/chips/ttl_74ls424.md) |
| Unknown | 74x425 | quad bus buffers, active low enables | [implemented](ttl_74xx/spec/chips/ttl_74x425.md) |
| Unknown | 74x426 | quad bus buffers, active high enables | [implemented](ttl_74xx/spec/chips/ttl_74x426.md) |
| Unknown | 74x428 | system controller for Intel 8080A (equivalent to Intel 8228) | [implemented](ttl_74xx/spec/chips/ttl_74x428.md) |
| Unknown | 74x429 | FIFO RAM controller | [implemented](ttl_74xx/spec/chips/ttl_74x429.md) |
| Unknown | 74x430 | cyclic redundancy checker/corrector | [pending](ttl_74xx/spec/chips/ttl_74x430.md) |
| Unknown | 74x432 | 8-bit multi-mode buffered latch | [implemented](ttl_74xx/spec/chips/ttl_74x432.md) |
| Unknown | 74x433 | 256-bit FIFO memory (64x4) | [implemented](ttl_74xx/spec/chips/ttl_74x433.md) |
| Unknown | 74x436 | line driver/memory driver circuits - MOS memory interface, damping output resistor | [implemented](ttl_74xx/spec/chips/ttl_74x436.md) |
| Unknown | 74x437 | line driver/memory driver circuits - MOS memory interface | [implemented](ttl_74xx/spec/chips/ttl_74x437.md) |
| Unknown | 74x438 | system controller for Intel 8080A (equivalent to Intel 8238) | [implemented](ttl_74xx/spec/chips/ttl_74x438.md) |
| Unknown | 74x440 | quad tridirectional bus transceiver, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x440.md) |
| Unknown | 74x441 | quad tridirectional bus transceiver, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x441.md) |
| Unknown | 74x442 | quad tridirectional bus transceiver, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x442.md) |
| Unknown | 74x443 | quad tridirectional bus transceiver, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x443.md) |
| Unknown | 74x444 | quad tridirectional bus transceiver, inverting and non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x444.md) |
| Unknown | 74x445 | BCD to decimal decoders/drivers | [implemented](ttl_74xx/spec/chips/ttl_74x445.md) |
| Unknown | 74x446 | quad bus transceivers, direction controls, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x446.md) |
| Unknown | 74x447 | BCD to 7-segment decoders/drivers, low voltage version of 74247 | [implemented](ttl_74xx/spec/chips/ttl_74x447.md) |
| Unknown | 74x448 | quad tridirectional bus transceiver, inverting and non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x448.md) |
| Unknown | 74x449 | quad bus transceivers, direction controls, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x449.md) |
| Unknown | 74450 | counter, latch, 7-segment decoder | [implemented](ttl_74xx/spec/chips/ttl_74450.md) |
| Unknown | 74S450 | 8192-bit PROM (1024x8) with power-down | [implemented](ttl_74xx/spec/chips/ttl_74s450.md) |
| Unknown | 74LS450 | 16-to-1 multiplexer, complementary outputs | [implemented](ttl_74xx/spec/chips/ttl_74ls450.md) |
| Unknown | 74S451 | 8192-bit PROM (1024x8) with power-down | [implemented](ttl_74xx/spec/chips/ttl_74s451.md) |
| Unknown | 74LS451 | dual 8-to-1 multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74ls451.md) |
| Unknown | 74x452 | dual decade counter, synchronous | [implemented](ttl_74xx/spec/chips/ttl_74x452.md) |
| Unknown | 74453 | dual binary counter, synchronous | [implemented](ttl_74xx/spec/chips/ttl_74453.md) |
| Unknown | 74LS453 | quad 4-to-1 multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74ls453.md) |
| Unknown | 74x454 | dual decade up/down counter, synchronous, preset input | [implemented](ttl_74xx/spec/chips/ttl_74x454.md) |
| Unknown | 74455 | dual binary up/down counter, synchronous, preset input | [implemented](ttl_74xx/spec/chips/ttl_74455.md) |
| Unknown | 74456 | 4-bit NBCD full adder | [implemented](ttl_74xx/spec/chips/ttl_74456.md) |
| Unknown | 74x458 | nines complement / zero element | [implemented](ttl_74xx/spec/chips/ttl_74x458.md) |
| Unknown | 74460 | 4-bit bus transfer switch | [implemented](ttl_74xx/spec/chips/ttl_74460.md) |
| Unknown | 74LS460 | 10-bit comparator | [implemented](ttl_74xx/spec/chips/ttl_74ls460.md) |
| Unknown | 74x461 | 8-bit presettable binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x461.md) |
| Unknown | 74x462 | fiber-optic data-link transmitter | [excluded](ttl_74xx/spec/chips/ttl_74x462.md) |
| Unknown | 74x463 | fiber-optic data-link receiver | [excluded](ttl_74xx/spec/chips/ttl_74x463.md) |
| Unknown | 74x465 | octal buffer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x465.md) |
| Unknown | 74x466 | octal buffers, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x466.md) |
| Unknown | 74x467 | octal buffers, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x467.md) |
| Unknown | 74x468 | octal buffers, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x468.md) |
| Unknown | 74x469 | 8-bit synchronous up/down counter, parallel load and hold capability | [implemented](ttl_74xx/spec/chips/ttl_74x469.md) |
| Unknown | 74x470 | 2048-bit PROM (256x8) | [implemented](ttl_74xx/spec/chips/ttl_74x470.md) |
| Unknown | 74x471 | 2048-bit PROM (256x8) | [implemented](ttl_74xx/spec/chips/ttl_74x471.md) |
| Unknown | 74x472 | 4096-bit PROM (512x8) | [implemented](ttl_74xx/spec/chips/ttl_74x472.md) |
| Unknown | 74x473 | 4096-bit PROM (512x8) | [implemented](ttl_74xx/spec/chips/ttl_74x473.md) |
| Unknown | 74x474 | 4096-bit PROM (512x8) | [implemented](ttl_74xx/spec/chips/ttl_74x474.md) |
| Unknown | 74x475 | 4096-bit PROM (512x8) | [implemented](ttl_74xx/spec/chips/ttl_74x475.md) |
| Unknown | 74x476 | 4096-bit PROM (1024x4) | [implemented](ttl_74xx/spec/chips/ttl_74x476.md) |
| Unknown | 74x477 | 4096-bit PROM (1024x4) | [implemented](ttl_74xx/spec/chips/ttl_74x477.md) |
| Unknown | 74x478 | 8192-bit PROM (1024x8) | [implemented](ttl_74xx/spec/chips/ttl_74x478.md) |
| Unknown | 74x479 | 8192-bit PROM (1024x8) | [implemented](ttl_74xx/spec/chips/ttl_74x479.md) |
| Unknown | 74x480 | single burst error recovery circuit | [implemented](ttl_74xx/spec/chips/ttl_74x480.md) |
| Unknown | 74x481 | 4-bit slice cascadable processor elements | [implemented](ttl_74xx/spec/chips/ttl_74x481.md) |
| Unknown | 74x482 | 4-bit slice expandable control elements | [implemented](ttl_74xx/spec/chips/ttl_74x482.md) |
| Unknown | 74x484 | BCD-to-binary converter | [implemented](ttl_74xx/spec/chips/ttl_74x484.md) |
| Unknown | 74x485 | binary-to-BCD converter | [implemented](ttl_74xx/spec/chips/ttl_74x485.md) |
| Unknown | 74x488 | IEEE-488 bus interface | [implemented](ttl_74xx/spec/chips/ttl_74x488.md) |
| Unknown | 74x490 | dual decade counter | [implemented](ttl_74xx/spec/chips/ttl_74x490.md) |
| Unknown | 74x491 | 10-bit binary up/down counter, limited preset | [implemented](ttl_74xx/spec/chips/ttl_74x491.md) |
| Unknown | 74x498 | 8-bit bidirectional shift register, parallel inputs | [implemented](ttl_74xx/spec/chips/ttl_74x498.md) |
| Unknown | 74x500 | 6-bit flash analog-to-digital converter (ADC) | [excluded](ttl_74xx/spec/chips/ttl_74x500.md) |
| Unknown | 74x502 | 8-bit successive approximation register | [implemented](ttl_74xx/spec/chips/ttl_74x502.md) |
| Unknown | 74x503 | 8-bit successive approximation register with expansion control | [implemented](ttl_74xx/spec/chips/ttl_74x503.md) |
| Unknown | 74x504 | 12-bit successive approximation register with expansion control | [implemented](ttl_74xx/spec/chips/ttl_74x504.md) |
| Unknown | 74x505 | 8-bit successive approximation ADC | [excluded](ttl_74xx/spec/chips/ttl_74x505.md) |
| Unknown | 74x508 | 8-bit multiplier/divider | [implemented](ttl_74xx/spec/chips/ttl_74x508.md) |
| Unknown | 74x515 | programmable mapping decoder (2-to-4 line decoder with 9 programmable enable inputs) | [implemented](ttl_74xx/spec/chips/ttl_74x515.md) |
| Unknown | 74x516 | 16-bit multiplier/divider | [implemented](ttl_74xx/spec/chips/ttl_74x516.md) |
| Unknown | 74x518 | 8-bit comparator | [implemented](ttl_74xx/spec/chips/ttl_74x518.md) |
| Unknown | 74x519 | 8-bit comparator | [implemented](ttl_74xx/spec/chips/ttl_74x519.md) |
| Unknown | 74x520 | 8-bit comparator, inverting output | [implemented](ttl_74xx/spec/chips/ttl_74x520.md) |
| Unknown | 74x521 | 8-bit comparator, inverting output | [implemented](ttl_74xx/spec/chips/ttl_74x521.md) |
| Unknown | 74x522 | 8-bit comparator, inverting output | [implemented](ttl_74xx/spec/chips/ttl_74x522.md) |
| Unknown | 74x524 | 8-bit registered comparator | [implemented](ttl_74xx/spec/chips/ttl_74x524.md) |
| Unknown | 74x525 | 16-bit programmable counter | [implemented](ttl_74xx/spec/chips/ttl_74x525.md) |
| Unknown | 74x526 | fuse programmable identity comparator, 16-bit | [implemented](ttl_74xx/spec/chips/ttl_74x526.md) |
| Unknown | 74x527 | fuse programmable identity comparator, 8-bit + 4-bit conventional Identity comparator | [implemented](ttl_74xx/spec/chips/ttl_74x527.md) |
| Unknown | 74x528 | fuse programmable Identity comparator, 12-bit | [implemented](ttl_74xx/spec/chips/ttl_74x528.md) |
| Unknown | 74x531 | octal transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x531.md) |
| Unknown | 74x532 | octal register | [implemented](ttl_74xx/spec/chips/ttl_74x532.md) |
| Unknown | 74x533 | octal D-type transparent latch, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x533.md) |
| Unknown | 74x534 | octal D-type edge-triggered flip-flop, inverting outputs, shared clock and output enable | [implemented](ttl_74xx/spec/chips/ttl_74x534.md) |
| Unknown | 74x535 | octal transparent latch, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x535.md) |
| Unknown | 74x536 | octal register, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x536.md) |
| Unknown | 74x537 | BCD to decimal decoder | [implemented](ttl_74xx/spec/chips/ttl_74x537.md) |
| Unknown | 74x538 | 3-to-8 line decoder/demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x538.md) |
| Unknown | 74x539 | dual 2-to-4 line decoder/demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x539.md) |
| Unknown | 74x540 | octal buffer, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x540.md) |
| Unknown | 74x541 | octal buffer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x541.md) |
| Unknown | 74x543 | octal registered transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x543.md) |
| Unknown | 74x544 | octal registered transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x544.md) |
| Unknown | 74x545 | octal bidirectional transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x545.md) |
| Unknown | 74x546 | 8-bit bidirectional registered transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x546.md) |
| Unknown | 74LS547 | 8-bit bidirectional latched transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74ls547.md) |
| Unknown | 74LS548 | 8-bit two-stage pipelined register | [implemented](ttl_74xx/spec/chips/ttl_74ls548.md) |
| Unknown | 74x549 | 8-bit two-stage pipelined latch | [implemented](ttl_74xx/spec/chips/ttl_74x549.md) |
| Unknown | 74x550 | octal registered transceiver with status flags, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x550.md) |
| Unknown | 74x551 | octal registered transceiver with status flags, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x551.md) |
| Unknown | 74x552 | octal registered transceiver with parity and flags | [implemented](ttl_74xx/spec/chips/ttl_74x552.md) |
| Unknown | 74x556 | 16x16-bit multiplier slice | [implemented](ttl_74xx/spec/chips/ttl_74x556.md) |
| Unknown | 74x557 | 8-bit by 8-bit multiplier | [implemented](ttl_74xx/spec/chips/ttl_74x557.md) |
| Unknown | 74x558 | 8-bit by 8-bit multiplier | [implemented](ttl_74xx/spec/chips/ttl_74x558.md) |
| Unknown | 74x559 | 8-bit expandable two's complement multiplier/divider | [implemented](ttl_74xx/spec/chips/ttl_74x559.md) |
| Unknown | 74x560 | 4-bit decade counter | [implemented](ttl_74xx/spec/chips/ttl_74x560.md) |
| Unknown | 74x561 | synchronous 4-bit binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x561.md) |
| Unknown | 74x563 | octal D-type transparent latch, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x563.md) |
| Unknown | 74x564 | octal D-type edge-triggered flip-flop, inverting outputs, shared clock and output enable | [implemented](ttl_74xx/spec/chips/ttl_74x564.md) |
| Unknown | 74x566 | 8-bit bidirectional registered transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x566.md) |
| Unknown | 74x567 | 8-bit bidirectional latched transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x567.md) |
| Unknown | 74x568 | decade up/down counter | [implemented](ttl_74xx/spec/chips/ttl_74x568.md) |
| Unknown | 74x569 | binary up/down counter | [implemented](ttl_74xx/spec/chips/ttl_74x569.md) |
| Unknown | 74x570 | 2048-bit PROM (512x4) | [implemented](ttl_74xx/spec/chips/ttl_74x570.md) |
| Unknown | 74x571 | 2048-bit PROM (512x4) | [implemented](ttl_74xx/spec/chips/ttl_74x571.md) |
| Unknown | 74x572 | 4096-bit PROM (1024x4) | [implemented](ttl_74xx/spec/chips/ttl_74x572.md) |
| Unknown | 74x573 | octal D-type transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x573.md) |
| Unknown | 74x574 | octal D-type edge-triggered flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x574.md) |
| Unknown | 74x575 | octal D-type edge-triggered flip-flop, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x575.md) |
| Unknown | 74x576 | octal D-type edge-triggered flip-flop, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x576.md) |
| Unknown | 74x577 | octal D-type edge-triggered flip-flop, synchronous clear, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x577.md) |
| Unknown | 74x579 | 8-bit bidirectional binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x579.md) |
| Unknown | 74x580 | octal D-type transparent latch, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x580.md) |
| Unknown | 74x582 | 4-bit BCD arithmetic logic unit | [implemented](ttl_74xx/spec/chips/ttl_74x582.md) |
| Unknown | 74x583 | 4-bit BCD adder | [implemented](ttl_74xx/spec/chips/ttl_74x583.md) |
| Unknown | 74x588 | octal bidirectional transceiver with IEEE-488 termination resistors | [implemented](ttl_74xx/spec/chips/ttl_74x588.md) |
| Unknown | 74x589 | 8-bit shift register, input latch | [implemented](ttl_74xx/spec/chips/ttl_74x589.md) |
| Unknown | 74x590 | 8-bit binary counter, output registers | [implemented](ttl_74xx/spec/chips/ttl_74x590.md) |
| Unknown | 74x591 | 8-bit binary counter, output registers | [implemented](ttl_74xx/spec/chips/ttl_74x591.md) |
| Unknown | 74x592 | 8-bit binary counter, input registers | [implemented](ttl_74xx/spec/chips/ttl_74x592.md) |
| Unknown | 74x593 | 8-bit binary counter, input registers | [implemented](ttl_74xx/spec/chips/ttl_74x593.md) |
| Unknown | 74x594 | 8-bit shift registers, serial-in, parallel-out, output latches | [implemented](ttl_74xx/spec/chips/ttl_74x594.md) |
| Unknown | 74x595 | 8-bit shift registers, serial-in, parallel-out, output latches, output enable | [implemented](ttl_74xx/spec/chips/ttl_74x595.md) |
| Unknown | 74x596 | 8-bit shift registers, serial-in, parallel-out, output latches, output enable | [implemented](ttl_74xx/spec/chips/ttl_74x596.md) |
| Unknown | 74x597 | 8-bit shift registers, parallel-in, serial-out, input latches | [implemented](ttl_74xx/spec/chips/ttl_74x597.md) |
| Unknown | 74x598 | 8-bit shift register, selectable parallel-in/out input latches | [implemented](ttl_74xx/spec/chips/ttl_74x598.md) |
| Unknown | 74x599 | 8-bit shift registers, serial-in, parallel-out, output latches | [implemented](ttl_74xx/spec/chips/ttl_74x599.md) |
| Unknown | 74x600 | dynamic memory refresh controller, transparent and burst modes, for 4K or 16K dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x600.md) |
| Unknown | 74x601 | dynamic memory refresh controller, transparent and burst modes, for 64K dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x601.md) |
| Unknown | 74x602 | dynamic memory refresh controller, cycle steal and burst modes, for 4K or 16K dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x602.md) |
| Unknown | 74x603 | dynamic memory refresh controller, cycle steal and burst modes, for 64K dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x603.md) |
| Unknown | 74x604 | octal 2-input multiplexer, latch, high-speed | [implemented](ttl_74xx/spec/chips/ttl_74x604.md) |
| Unknown | 74x605 | octal 2-input multiplexer, latch, high-speed | [implemented](ttl_74xx/spec/chips/ttl_74x605.md) |
| Unknown | 74x606 | octal 2-input multiplexer, latch, glitch-free | [implemented](ttl_74xx/spec/chips/ttl_74x606.md) |
| Unknown | 74x607 | octal 2-input multiplexer, latch, glitch-free | [implemented](ttl_74xx/spec/chips/ttl_74x607.md) |
| Unknown | 74x608 | memory cycle controller | [implemented](ttl_74xx/spec/chips/ttl_74x608.md) |
| Unknown | 74x610 | memory mapper, latched | [implemented](ttl_74xx/spec/chips/ttl_74x610.md) |
| Unknown | 74x611 | memory mapper, latched | [implemented](ttl_74xx/spec/chips/ttl_74x611.md) |
| Unknown | 74x612 | memory mapper | [implemented](ttl_74xx/spec/chips/ttl_74x612.md) |
| Unknown | 74x613 | memory mapper | [implemented](ttl_74xx/spec/chips/ttl_74x613.md) |
| Unknown | 74x614 | octal bus transceiver and register, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x614.md) |
| Unknown | 74x615 | octal bus transceiver and register, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x615.md) |
| Unknown | 74x616 | 16-bit parallel error detection and correction | [implemented](ttl_74xx/spec/chips/ttl_74x616.md) |
| Unknown | 74x617 | 16-bit parallel error detection and correction | [implemented](ttl_74xx/spec/chips/ttl_74x617.md) |
| Unknown | 74x620 | octal bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x620.md) |
| Unknown | 74x621 | octal bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x621.md) |
| Unknown | 74x622 | octal bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x622.md) |
| Unknown | 74x623 | octal bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x623.md) |
| Unknown | 74x624 | voltage-controlled oscillator, enable control, range control, two-phase outputs | [excluded](ttl_74xx/spec/chips/ttl_74x624.md) |
| Unknown | 74x625 | dual voltage-controlled oscillator, two-phase outputs | [excluded](ttl_74xx/spec/chips/ttl_74x625.md) |
| Unknown | 74x626 | dual voltage-controlled oscillator, enable control, two-phase outputs | [excluded](ttl_74xx/spec/chips/ttl_74x626.md) |
| Unknown | 74x627 | dual voltage-controlled oscillator | [excluded](ttl_74xx/spec/chips/ttl_74x627.md) |
| Unknown | 74x628 | voltage-controlled oscillator, enable control, range control, external temperature compensation, two-phase outputs | [excluded](ttl_74xx/spec/chips/ttl_74x628.md) |
| Unknown | 74x629 | dual voltage-controlled oscillator, enable control, range control | [excluded](ttl_74xx/spec/chips/ttl_74x629.md) |
| Unknown | 74x630 | 16-bit error detection and correction (EDAC) | [implemented](ttl_74xx/spec/chips/ttl_74x630.md) |
| Unknown | 74x631 | 16-bit error detection and correction | [implemented](ttl_74xx/spec/chips/ttl_74x631.md) |
| Unknown | 74x632 | 32-bit parallel error detection and correction, byte-write | [implemented](ttl_74xx/spec/chips/ttl_74x632.md) |
| Unknown | 74x633 | 32-bit parallel error detection and correction, byte-write | [implemented](ttl_74xx/spec/chips/ttl_74x633.md) |
| Unknown | 74x634 | 32-bit parallel error detection and correction | [implemented](ttl_74xx/spec/chips/ttl_74x634.md) |
| Unknown | 74x635 | 32-bit parallel error detection and correction | [implemented](ttl_74xx/spec/chips/ttl_74x635.md) |
| Unknown | 74x636 | 8-bit parallel error detection and correction | [implemented](ttl_74xx/spec/chips/ttl_74x636.md) |
| Unknown | 74x637 | 8-bit parallel error detection and correction | [implemented](ttl_74xx/spec/chips/ttl_74x637.md) |
| Unknown | 74x638 | octal bus transceiver, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x638.md) |
| Unknown | 74x639 | octal bus transceiver, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x639.md) |
| Unknown | 74x640 | octal bus transceiver, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x640.md) |
| Unknown | 74x641 | octal bus transceiver, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x641.md) |
| Unknown | 74x642 | octal bus transceiver, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x642.md) |
| Unknown | 74x643 | octal bus transceiver, mix of inverting and non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x643.md) |
| Unknown | 74x644 | octal bus transceiver, mix of inverting and non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x644.md) |
| Unknown | 74x645 | octal bus transceiver, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x645.md) |
| Unknown | 74x646 | octal bus transceiver/latch/multiplexer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x646.md) |
| Unknown | 74x647 | octal bus transceiver/latch/multiplexer, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x647.md) |
| Unknown | 74x648 | octal bus transceiver/latch/multiplexer, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x648.md) |
| Unknown | 74x649 | octal bus transceiver/latch/multiplexer, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x649.md) |
| Unknown | 74x651 | octal bus transceiver/register, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x651.md) |
| Unknown | 74x652 | octal bus transceiver/register, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x652.md) |
| Unknown | 74x653 | octal bus transceiver/register, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x653.md) |
| Unknown | 74x654 | octal bus transceiver/register, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x654.md) |
| Unknown | 74x655 | octal buffer / line driver with parity, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x655.md) |
| Unknown | 74x656 | octal buffer / line driver with parity, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x656.md) |
| Unknown | 74x657 | octal bidirectional transceiver with 8-bit parity generator/checker | [implemented](ttl_74xx/spec/chips/ttl_74x657.md) |
| Unknown | 74x658 | octal bus transceiver, parity, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x658.md) |
| Unknown | 74x659 | octal bus transceiver, parity, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x659.md) |
| Unknown | 74x664 | octal bus transceiver, parity, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x664.md) |
| Unknown | 74x665 | octal bus transceiver, parity, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x665.md) |
| Unknown | 74x666 | 8-bit D-type transparent read-back latch, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x666.md) |
| Unknown | 74x667 | 8-bit D-type transparent read-back latch, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x667.md) |
| Unknown | 74x668 | synchronous 4-bit decade up/down counter | [implemented](ttl_74xx/spec/chips/ttl_74x668.md) |
| Unknown | 74x669 | synchronous 4-bit binary up/down counter | [implemented](ttl_74xx/spec/chips/ttl_74x669.md) |
| Unknown | 74x670 | 16-bit register file (4x4) | [implemented](ttl_74xx/spec/chips/ttl_74x670.md) |
| Unknown | 74x671 | 4-bit bidirectional shift register/latch/multiplexer, direct clear | [implemented](ttl_74xx/spec/chips/ttl_74x671.md) |
| Unknown | 74x672 | 4-bit bidirectional shift register/latch/multiplexer, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x672.md) |
| Unknown | 74x673 | 16-bit serial-in, serial/parallel-out shift register, output storage registers | [implemented](ttl_74xx/spec/chips/ttl_74x673.md) |
| Unknown | 74x674 | 16-bit parallel-in, serial-out shift register | [implemented](ttl_74xx/spec/chips/ttl_74x674.md) |
| Unknown | 74x675 | 16-bit serial-in, serial/parallel-out shift register | [implemented](ttl_74xx/spec/chips/ttl_74x675.md) |
| Unknown | 74x676 | 16-bit serial/parallel-in, serial-out shift register | [implemented](ttl_74xx/spec/chips/ttl_74x676.md) |
| Unknown | 74x677 | 16-bit address comparator, enable | [implemented](ttl_74xx/spec/chips/ttl_74x677.md) |
| Unknown | 74x678 | 16-bit address comparator, latch | [implemented](ttl_74xx/spec/chips/ttl_74x678.md) |
| Unknown | 74x679 | 12-bit address comparator, latch | [implemented](ttl_74xx/spec/chips/ttl_74x679.md) |
| Unknown | 74x680 | 12-bit address comparator, enable | [implemented](ttl_74xx/spec/chips/ttl_74x680.md) |
| Unknown | 74x681 | 4-bit parallel binary accumulator | [implemented](ttl_74xx/spec/chips/ttl_74x681.md) |
| Unknown | 74x682 | 8-bit magnitude comparator, P>Q output | [implemented](ttl_74xx/spec/chips/ttl_74x682.md) |
| Unknown | 74x683 | 8-bit magnitude comparator, P>Q output | [implemented](ttl_74xx/spec/chips/ttl_74x683.md) |
| Unknown | 74x684 | 8-bit magnitude comparator, P>Q output | [implemented](ttl_74xx/spec/chips/ttl_74x684.md) |
| Unknown | 74x685 | 8-bit magnitude comparator, P>Q output | [implemented](ttl_74xx/spec/chips/ttl_74x685.md) |
| Unknown | 74x686 | 8-bit magnitude comparator, P>Q output, enable | [implemented](ttl_74xx/spec/chips/ttl_74x686.md) |
| Unknown | 74x687 | 8-bit magnitude comparator, P>Q output, enable | [implemented](ttl_74xx/spec/chips/ttl_74x687.md) |
| Unknown | 74x688 | 8-bit magnitude comparator, enable | [implemented](ttl_74xx/spec/chips/ttl_74x688.md) |
| Unknown | 74x689 | 8-bit magnitude comparator, enable | [implemented](ttl_74xx/spec/chips/ttl_74x689.md) |
| Unknown | 74x690 | 4-bit decimal counter/latch/multiplexer, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x690.md) |
| Unknown | 74x691 | 4-bit binary counter/latch/multiplexer, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x691.md) |
| Unknown | 74x692 | 4-bit decimal counter/latch/multiplexer, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x692.md) |
| Unknown | 74x693 | 4-bit binary counter/latch/multiplexer, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x693.md) |
| Unknown | 74x694 | 4-bit decimal counter/latch/multiplexer, synchronous and asynchronous clears | [pending](ttl_74xx/spec/chips/ttl_74x694.md) |
| Unknown | 74x695 | 4-bit binary counter/latch/multiplexer, synchronous and asynchronous clears | [pending](ttl_74xx/spec/chips/ttl_74x695.md) |
| Unknown | 74x696 | 4-bit decimal counter/register/multiplexer, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x696.md) |
| Unknown | 74x697 | 4-bit binary counter/register/multiplexer, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x697.md) |
| Unknown | 74x698 | 4-bit decimal counter/register/multiplexer, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x698.md) |
| Unknown | 74x699 | 4-bit binary counter/register/multiplexer, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x699.md) |
| Unknown | 74x700 | octal dRAM driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x700.md) |
| Unknown | 74x701 | 8-bit register/counter/comparator | [pending](ttl_74xx/spec/chips/ttl_74x701.md) |
| Unknown | 74x702 | 8-bit registered read-back transceiver | [pending](ttl_74xx/spec/chips/ttl_74x702.md) |
| Unknown | 74x705 | arithmetic logic unit for digital signal processing applications | [pending](ttl_74xx/spec/chips/ttl_74x705.md) |
| Unknown | 74x707 | 8-bit TTL-ECL shift register | [pending](ttl_74xx/spec/chips/ttl_74x707.md) |
| Unknown | 74x708 | 576-bit FIFO memory (64x9) | [implemented](ttl_74xx/spec/chips/ttl_74x708.md) |
| Unknown | 74x710 | 8-bit single-supply TTL-ECL shift register | [pending](ttl_74xx/spec/chips/ttl_74x710.md) |
| Unknown | 74x711 | quint 2-to-1 multiplexers | [implemented](ttl_74xx/spec/chips/ttl_74x711.md) |
| Unknown | 74x712 | quint 3-to-1 multiplexers | [implemented](ttl_74xx/spec/chips/ttl_74x712.md) |
| Unknown | 74x715 | programmable video sync generator | [pending](ttl_74xx/spec/chips/ttl_74x715.md) |
| Unknown | 74x716 | programmable decade counter | [implemented](ttl_74xx/spec/chips/ttl_74x716.md) |
| Unknown | 74x718 | programmable binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x718.md) |
| Unknown | 74x723 | 576-bit FIFO memory (64x9) | [implemented](ttl_74xx/spec/chips/ttl_74x723.md) |
| Unknown | 74x724 | voltage-controlled multivibrator | [excluded](ttl_74xx/spec/chips/ttl_74x724.md) |
| Unknown | 74x725 | 4608-bit FIFO memory (512x9) | [implemented](ttl_74xx/spec/chips/ttl_74x725.md) |
| Unknown | 74x730 | octal dRAM driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x730.md) |
| Unknown | 74x731 | octal dRAM driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x731.md) |
| Unknown | 74x732 | 4-bit 3-bus multiplexer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x732.md) |
| Unknown | 74x733 | 4-bit 3-bus multiplexer, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x733.md) |
| Unknown | 74x734 | octal dRAM driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x734.md) |
| Unknown | 74x740 | dual 4-bit line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x740.md) |
| Unknown | 74x741 | dual 4-bit line driver, non-inverting, complementary enable inputs | [implemented](ttl_74xx/spec/chips/ttl_74x741.md) |
| Unknown | 74x742 | octal line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x742.md) |
| Unknown | 74x743 | octal line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x743.md) |
| Unknown | 74x744 | dual 4-bit line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x744.md) |
| Unknown | 74x746 | octal buffer / line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x746.md) |
| Unknown | 74x747 | octal buffer / line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x747.md) |
| Unknown | 74x748 | 8 to 3-line priority encoder (glitch-less) | [implemented](ttl_74xx/spec/chips/ttl_74x748.md) |
| Unknown | 74x756 | octal buffer/line driver, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x756.md) |
| Unknown | 74x757 | octal buffer/line driver, non-inverting outputs, complementary enable inputs | [implemented](ttl_74xx/spec/chips/ttl_74x757.md) |
| Unknown | 74x758 | quadruple bus transceivers, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x758.md) |
| Unknown | 74x759 | quadruple bus transceivers, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x759.md) |
| Unknown | 74x760 | octal buffer/line driver, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x760.md) |
| Unknown | 74x762 | octal buffer/line driver, inverting and non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x762.md) |
| Unknown | 74x763 | octal buffer/line driver, inverting outputs, complementary enable inputs | [implemented](ttl_74xx/spec/chips/ttl_74x763.md) |
| Unknown | 74x764 | dual-port dRAM controller | [pending](ttl_74xx/spec/chips/ttl_74x764.md) |
| Unknown | 74x765 | dual-port dRAM controller with address latch | [pending](ttl_74xx/spec/chips/ttl_74x765.md) |
| Unknown | 74x776 | 8-bit latched transceiver for FutureBus | [pending](ttl_74xx/spec/chips/ttl_74x776.md) |
| Unknown | 74x777 | triple latched transceiver | [pending](ttl_74xx/spec/chips/ttl_74x777.md) |
| Unknown | 74x779 | 8-bit bidirectional binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x779.md) |
| Unknown | 74x783 | synchronous address multiplexer for display systems | [pending](ttl_74xx/spec/chips/ttl_74x783.md) |
| Unknown | 74x784 | 8-bit serial/parallel multiplier with adder/subtractor | [pending](ttl_74xx/spec/chips/ttl_74x784.md) |
| Unknown | 74x785 | synchronous address multiplexer for display systems with 256-column refresh | [pending](ttl_74xx/spec/chips/ttl_74x785.md) |
| Unknown | 74x786 | 4-input asynchronous bus arbiter | [pending](ttl_74xx/spec/chips/ttl_74x786.md) |
| Unknown | 74x790 | error detection and correction (EDAC) | [pending](ttl_74xx/spec/chips/ttl_74x790.md) |
| Unknown | 74x793 | 8-bit latch, readback | [implemented](ttl_74xx/spec/chips/ttl_74x793.md) |
| Unknown | 74x794 | 8-bit register, readback | [implemented](ttl_74xx/spec/chips/ttl_74x794.md) |
| Unknown | 74x795 | octal buffer, non-inverting, shared enable | [implemented](ttl_74xx/spec/chips/ttl_74x795.md) |
| Unknown | 74x796 | octal buffer, inverting, shared enable | [implemented](ttl_74xx/spec/chips/ttl_74x796.md) |
| Unknown | 74x797 | octal buffer, non-inverting, enable for 4 buffers each | [implemented](ttl_74xx/spec/chips/ttl_74x797.md) |
| Unknown | 74x798 | octal buffer, inverting, enable for 4 buffers each | [implemented](ttl_74xx/spec/chips/ttl_74x798.md) |
| Unknown | 74x800 | triple 4-input AND/NAND drivers | [implemented](ttl_74xx/spec/chips/ttl_74x800.md) |
| Unknown | 74x802 | triple 4-input OR/NOR drivers | [implemented](ttl_74xx/spec/chips/ttl_74x802.md) |
| Unknown | 74x803 | quad D flip flops with matched propagation delays | [implemented](ttl_74xx/spec/chips/ttl_74x803.md) |
| Unknown | 74x804 | hex 2-input NAND drivers | [implemented](ttl_74xx/spec/chips/ttl_74x804.md) |
| Unknown | 74x805 | hex 2-input NOR drivers | [implemented](ttl_74xx/spec/chips/ttl_74x805.md) |
| Unknown | 74x807 | 1-to-10 clock driver | [implemented](ttl_74xx/spec/chips/ttl_74x807.md) |
| Unknown | 74x808 | hex 2-input AND drivers | [implemented](ttl_74xx/spec/chips/ttl_74x808.md) |
| Unknown | 74x810 | quad 2-input XNOR gates | [implemented](ttl_74xx/spec/chips/ttl_74x810.md) |
| Unknown | 74x811 | quad 2-input XNOR gates | [implemented](ttl_74xx/spec/chips/ttl_74x811.md) |
| Unknown | 74x817 | GTL+ to LV-TTL 1-to-6 fanout / LV-TTL to GTL+ 1-to-2 fanout driver | [implemented](ttl_74xx/spec/chips/ttl_74x817.md) |
| Unknown | 74x818 | 8-bit diagnostic register | [implemented](ttl_74xx/spec/chips/ttl_74x818.md) |
| Unknown | 74x819 | 8-bit diagnostic / pipeline register | [pending](ttl_74xx/spec/chips/ttl_74x819.md) |
| Unknown | 74x821 | 10-bit bus interface flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x821.md) |
| Unknown | 74x822 | 10-bit bus interface flip-flop, inverting inputs | [implemented](ttl_74xx/spec/chips/ttl_74x822.md) |
| Unknown | 74x823 | 9-bit D-type flip-flops, clear and clock enable inputs | [implemented](ttl_74xx/spec/chips/ttl_74x823.md) |
| Unknown | 74x824 | 9-bit D-type flip-flops, clear and clock enable inputs, inverting inputs | [implemented](ttl_74xx/spec/chips/ttl_74x824.md) |
| Unknown | 74x825 | 8-bit D-type flip-flop, clear and clock enable inputs | [implemented](ttl_74xx/spec/chips/ttl_74x825.md) |
| Unknown | 74x826 | 8-bit D-type flip-flop, clear and clock enable inputs, inverting inputs | [implemented](ttl_74xx/spec/chips/ttl_74x826.md) |
| Unknown | 74x827 | 10-bit buffer, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x827.md) |
| Unknown | 74x828 | 10-bit buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x828.md) |
| Unknown | 74x832 | hex 2-input OR drivers | [implemented](ttl_74xx/spec/chips/ttl_74x832.md) |
| Unknown | 74x833 | 8-bit to 9-bit bus transceiver with parity register, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x833.md) |
| Unknown | 74x834 | 8-bit to 9-bit bus transceiver with parity register, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x834.md) |
| Unknown | 74x835 | 8-bit shift register with 2:1 input multiplexers, one input latched, serial output | [implemented](ttl_74xx/spec/chips/ttl_74x835.md) |
| Unknown | 74x839 | field-programmable logic array 14x32x6 | [pending](ttl_74xx/spec/chips/ttl_74x839.md) |
| Unknown | 74x840 | field-programmable logic array 14x32x6 | [pending](ttl_74xx/spec/chips/ttl_74x840.md) |
| Unknown | 74x841 | 10-bit D-type flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x841.md) |
| Unknown | 74x842 | 10-bit D-type flip-flop, inverting inputs | [implemented](ttl_74xx/spec/chips/ttl_74x842.md) |
| Unknown | 74x843 | 9-bit D flip-flops, clear and set inputs | [implemented](ttl_74xx/spec/chips/ttl_74x843.md) |
| Unknown | 74x844 | 9-bit D flip-flops, clear and set inputs, inverting inputs | [implemented](ttl_74xx/spec/chips/ttl_74x844.md) |
| Unknown | 74x845 | 8-bit D flip-flops, clear and set inputs | [implemented](ttl_74xx/spec/chips/ttl_74x845.md) |
| Unknown | 74x846 | 8-bit D flip-flops, clear and set inputs, inverting inputs | [implemented](ttl_74xx/spec/chips/ttl_74x846.md) |
| Unknown | 74x848 | 8 to 3-line priority encoder (glitch-less) | [pending](ttl_74xx/spec/chips/ttl_74x848.md) |
| Unknown | 74x850 | 1 of 16 data selector/multiplexer, clocked select | [implemented](ttl_74xx/spec/chips/ttl_74x850.md) |
| Unknown | 74x851 | 1 of 16 data selector/multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x851.md) |
| Unknown | 74x852 | 8-bit universal transceiver port controller | [pending](ttl_74xx/spec/chips/ttl_74x852.md) |
| Unknown | 74x853 | 8-bit to 9-bit bus transceiver with parity latch, non-inverting | [pending](ttl_74xx/spec/chips/ttl_74x853.md) |
| Unknown | 74x854 | 8-bit to 9-bit bus transceiver with parity latch, inverting | [pending](ttl_74xx/spec/chips/ttl_74x854.md) |
| Unknown | 74x856 | 8-bit universal transceiver port controller | [pending](ttl_74xx/spec/chips/ttl_74x856.md) |
| Unknown | 74x857 | hex 2-line to 1-line multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x857.md) |
| Unknown | 74x861 | 10-bit bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x861.md) |
| Unknown | 74x862 | 10-bit bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x862.md) |
| Unknown | 74x863 | 9-bit bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x863.md) |
| Unknown | 74x864 | 9-bit bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x864.md) |
| Unknown | 74x866 | 8-bit magnitude comparator with latches | [implemented](ttl_74xx/spec/chips/ttl_74x866.md) |
| Unknown | 74x867 | synchronous 8-bit up/down counter, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x867.md) |
| Unknown | 74x869 | synchronous 8-bit up/down counter, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x869.md) |
| Unknown | 74x870 | dual 16x4 register files | [implemented](ttl_74xx/spec/chips/ttl_74x870.md) |
| Unknown | 74x871 | dual 16x4 register files | [implemented](ttl_74xx/spec/chips/ttl_74x871.md) |
| Unknown | 74x873 | dual 4-bit transparent latch with clear | [implemented](ttl_74xx/spec/chips/ttl_74x873.md) |
| Unknown | 74x874 | dual 4-bit edge-triggered D flip-flops with clear | [implemented](ttl_74xx/spec/chips/ttl_74x874.md) |
| Unknown | 74x876 | dual 4-bit edge-triggered D flip-flops with set, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x876.md) |
| Unknown | 74x877 | 8-bit universal transceiver port controller | [pending](ttl_74xx/spec/chips/ttl_74x877.md) |
| Unknown | 74x878 | dual 4-bit D-type flip-flop, synchronous clear, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x878.md) |
| Unknown | 74x879 | dual 4-bit D-type flip-flop, synchronous clear, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x879.md) |
| Unknown | 74x880 | dual 4-bit transparent latch with clear, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x880.md) |
| Unknown | 74x881 | 4-bit arithmetic logic unit | [implemented](ttl_74xx/spec/chips/ttl_74x881.md) |
| Unknown | 74x882 | 32-bit lookahead carry generator | [implemented](ttl_74xx/spec/chips/ttl_74x882.md) |
| Unknown | 74x885 | 8-bit magnitude comparator | [implemented](ttl_74xx/spec/chips/ttl_74x885.md) |
| Unknown | 74x887 | 8-bit processor element (non-cascadable version of 74x888) | [pending](ttl_74xx/spec/chips/ttl_74x887.md) |
| Unknown | 74x888 | 8-bit processor slice | [pending](ttl_74xx/spec/chips/ttl_74x888.md) |
| Unknown | 74x889 | 8-bit processor slice | [pending](ttl_74xx/spec/chips/ttl_74x889.md) |
| Unknown | 74x890 | microoperation sequencer | [pending](ttl_74xx/spec/chips/ttl_74x890.md) |
| Unknown | 74x891 | microoperation sequencer | [pending](ttl_74xx/spec/chips/ttl_74x891.md) |
| Unknown | 74x895 | 8-bit memory address generator | [pending](ttl_74xx/spec/chips/ttl_74x895.md) |
| Unknown | 74x897 | 16-bit parallel/serial barrel shifter | [pending](ttl_74xx/spec/chips/ttl_74x897.md) |
| Unknown | 74x899 | 9-bit latchable transceiver with parity generator / checker | [pending](ttl_74xx/spec/chips/ttl_74x899.md) |
| Unknown | 74x900 | quad 2-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x900.md) |
| Unknown | 74x901 | hex inverting TTL buffer | [implemented](ttl_74xx/spec/chips/ttl_74x901.md) |
| Unknown | 74x904 | hex non-inverting PMOS buffer | [implemented](ttl_74xx/spec/chips/ttl_74x904.md) |
| Unknown | 74x905 | 12-bit successive approximation register | [pending](ttl_74xx/spec/chips/ttl_74x905.md) |
| Unknown | 74x906 | hex open drain n-channel buffers | [implemented](ttl_74xx/spec/chips/ttl_74x906.md) |
| Unknown | 74x907 | hex open drain p-channel buffers | [implemented](ttl_74xx/spec/chips/ttl_74x907.md) |
| Unknown | 74x908 | dual 2-input NAND 30 V / 250 mA relay driver | [implemented](ttl_74xx/spec/chips/ttl_74x908.md) |
| Unknown | 74x909 | quad voltage comparator | [excluded](ttl_74xx/spec/chips/ttl_74x909.md) |
| Unknown | 74x910 | 256-bit RAM (64x4) | [implemented](ttl_74xx/spec/chips/ttl_74x910.md) |
| Unknown | 74x911 | 4-digit expandable display controller | [implemented](ttl_74xx/spec/chips/ttl_74x911.md) |
| Unknown | 74x912 | 6-digit BCD display controller and driver | [implemented](ttl_74xx/spec/chips/ttl_74x912.md) |
| Unknown | 74x913 | 6-digit BCD display controller and driver, no decimal point | [implemented](ttl_74xx/spec/chips/ttl_74x913.md) |
| Unknown | 74x914 | hex inverter gate, extended input voltage | [implemented](ttl_74xx/spec/chips/ttl_74x914.md) |
| Unknown | 74x915 | 7-segment to BCD converter | [implemented](ttl_74xx/spec/chips/ttl_74x915.md) |
| Unknown | 74x917 | 6-digit hex display controller and driver | [implemented](ttl_74xx/spec/chips/ttl_74x917.md) |
| Unknown | 74x918 | dual 2-input NAND 30 V / 250 mA relay driver | [implemented](ttl_74xx/spec/chips/ttl_74x918.md) |
| Unknown | 74x920 | 1024-bit RAM (256x4), separate data inputs and outputs | [implemented](ttl_74xx/spec/chips/ttl_74x920.md) |
| Unknown | 74x921 | 1024-bit RAM (256x4) | [implemented](ttl_74xx/spec/chips/ttl_74x921.md) |
| Unknown | 74x922 | 16-key encoder | [implemented](ttl_74xx/spec/chips/ttl_74x922.md) |
| Unknown | 74x923 | 20-key encoder | [implemented](ttl_74xx/spec/chips/ttl_74x923.md) |
| Unknown | 74x925 | 4-digit counter/display driver | [pending](ttl_74xx/spec/chips/ttl_74x925.md) |
| Unknown | 74x926 | 4-digit decade counter/display driver, carry out and latch (up to 9999) | [pending](ttl_74xx/spec/chips/ttl_74x926.md) |
| Unknown | 74x927 | 4-digit timer counter/display driver (up to 9599, intended as time elapsed, i.e. 9:59.9 min) | [pending](ttl_74xx/spec/chips/ttl_74x927.md) |
| Unknown | 74x928 | 4-digit counter/display driver (up to 1999) | [pending](ttl_74xx/spec/chips/ttl_74x928.md) |
| Unknown | 74x929 | 1024-bit RAM (1024x1), single chip select | [implemented](ttl_74xx/spec/chips/ttl_74x929.md) |
| Unknown | 74x930 | 1024-bit RAM (1024x1), three chip selects | [implemented](ttl_74xx/spec/chips/ttl_74x930.md) |
| Unknown | 74x932 | phase comparator | [pending](ttl_74xx/spec/chips/ttl_74x932.md) |
| Unknown | 74x933 | 7-bit address bus comparator | [implemented](ttl_74xx/spec/chips/ttl_74x933.md) |
| Unknown | 74934 | ADC similar to ADC0829, see corresponding NSC datasheet | [excluded](ttl_74xx/spec/chips/ttl_74934.md) |
| Unknown | 74x935 | ADC for 3.5-digit digital voltmeters, multiplexed 7-segment display outputs | [excluded](ttl_74xx/spec/chips/ttl_74x935.md) |
| Unknown | 74x936 | ADC for 3.75-digit digital voltmeters, multiplexed 7-segment display outputs | [excluded](ttl_74xx/spec/chips/ttl_74x936.md) |
| Unknown | 74x937 | ADC for 3.5-digit digital voltmeters, multiplexed BCD outputs | [excluded](ttl_74xx/spec/chips/ttl_74x937.md) |
| Unknown | 74x938 | ADC for 3.75-digit digital voltmeters, multiplexed BCD outputs | [excluded](ttl_74xx/spec/chips/ttl_74x938.md) |
| Unknown | 74x940 | octal bus/line drivers/line receivers | [implemented](ttl_74xx/spec/chips/ttl_74x940.md) |
| Unknown | 74x941 | octal bus/line drivers/line receivers | [implemented](ttl_74xx/spec/chips/ttl_74x941.md) |
| Unknown | 74x942 | 300 baud Bell 103 modem (+/- 5 V supply) | [pending](ttl_74xx/spec/chips/ttl_74x942.md) |
| Unknown | 74x943 | 300 baud Bell 103 modem (single 5 V supply) | [pending](ttl_74xx/spec/chips/ttl_74x943.md) |
| Unknown | 74x945 | 4-digit up/down counter, decoder and LCD driver, output latch | [pending](ttl_74xx/spec/chips/ttl_74x945.md) |
| Unknown | 74x946 | 4.5-digit counter, decoder and LCD driver, leading zero blanking | [pending](ttl_74xx/spec/chips/ttl_74x946.md) |
| Unknown | 74x947 | 4-digit up/down counter, decoder and LCD driver, leading zero blanking | [pending](ttl_74xx/spec/chips/ttl_74x947.md) |
| Unknown | 74x948 | 8-bit ADC with 16-channel analog multiplexer | [excluded](ttl_74xx/spec/chips/ttl_74x948.md) |
| Unknown | 74x949 | 8-bit ADC with 8-channel analog multiplexer | [excluded](ttl_74xx/spec/chips/ttl_74x949.md) |
| Unknown | 74x950 | 8-bit ADC with 8-channel analog multiplexer and sample and hold | [excluded](ttl_74xx/spec/chips/ttl_74x950.md) |
| Unknown | 74x952 | dual rank 8-bit shift register, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x952.md) |
| Unknown | 74x962 | dual rank 8-bit shift register, register exchange mode | [implemented](ttl_74xx/spec/chips/ttl_74x962.md) |
| Unknown | 74x963 | dual rank 8-bit shift register, synchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x963.md) |
| Unknown | 74x964 | dual rank 8-bit shift register, synchronous and asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x964.md) |
| Unknown | 74x968 | controller/driver for 16k/64k/256k/1M dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x968.md) |
| Unknown | 74x978 | octal flip-flop with serial scanner | [implemented](ttl_74xx/spec/chips/ttl_74x978.md) |
| Unknown | 74x979 | 9-bit registered transceiver with parity generator/checker for FutureBus | [implemented](ttl_74xx/spec/chips/ttl_74x979.md) |
| Unknown | 74x989 | 64-bit RAM (16x4), inverting output | [implemented](ttl_74xx/spec/chips/ttl_74x989.md) |
| Unknown | 74x990 | 8-bit D-type transparent read-back latch, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x990.md) |
| Unknown | 74x991 | 8-bit D-type transparent read-back latch, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x991.md) |
| Unknown | 74x992 | 9-bit D-type transparent read-back latch, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x992.md) |
| Unknown | 74x993 | 9-bit D-type transparent read-back latch, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x993.md) |
| Unknown | 74x994 | 10-bit D-type transparent read-back latch, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x994.md) |
| Unknown | 74x995 | 10-bit D-type transparent read-back latch, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x995.md) |
| Unknown | 74x996 | 8-bit D-type edge-triggered read-back latch | [implemented](ttl_74xx/spec/chips/ttl_74x996.md) |
| Unknown | 74x1000 | quad 2-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x1000.md) |
| Unknown | 74x1002 | quad 2-input NOR gate | [implemented](ttl_74xx/spec/chips/ttl_74x1002.md) |
| Unknown | 74x1003 | quad 2-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x1003.md) |
| Unknown | 74x1004 | hex inverting buffer | [implemented](ttl_74xx/spec/chips/ttl_74x1004.md) |
| Unknown | 74x1005 | hex inverting buffer | [implemented](ttl_74xx/spec/chips/ttl_74x1005.md) |
| Unknown | 74x1008 | quad 2-input AND gate | [implemented](ttl_74xx/spec/chips/ttl_74x1008.md) |
| Unknown | 74x1011 | triple 3-input AND gate | [implemented](ttl_74xx/spec/chips/ttl_74x1011.md) |
| Unknown | 74x1017 | 16x16-bit parallel multiplier | [pending](ttl_74xx/spec/chips/ttl_74x1017.md) |
| Unknown | 74x1018 | 18-bit Schottky diode R-C bus termination array | [excluded](ttl_74xx/spec/chips/ttl_74x1018.md) |
| Unknown | 74x1020 | dual 4-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x1020.md) |
| Unknown | 74x1032 | quad 2-input OR gate | [implemented](ttl_74xx/spec/chips/ttl_74x1032.md) |
| Unknown | 74x1034 | hex non-inverting buffer | [implemented](ttl_74xx/spec/chips/ttl_74x1034.md) |
| Unknown | 74x1035 | hex non-inverting buffer | [implemented](ttl_74xx/spec/chips/ttl_74x1035.md) |
| Unknown | 74x1036 | quad 2-input NOR gate | [implemented](ttl_74xx/spec/chips/ttl_74x1036.md) |
| Unknown | 74x1050 | 12-bit Schottky diode bus termination array, clamp to GND | [excluded](ttl_74xx/spec/chips/ttl_74x1050.md) |
| Unknown | 74x1051 | 12-bit Schottky diode bus termination array, clamp to GND/V | [excluded](ttl_74xx/spec/chips/ttl_74x1051.md) |
| Unknown | 74x1052 | 16-bit Schottky diode bus termination array, clamp to GND | [excluded](ttl_74xx/spec/chips/ttl_74x1052.md) |
| Unknown | 74x1053 | 16-bit Schottky diode bus termination array, clamp to GND/V | [excluded](ttl_74xx/spec/chips/ttl_74x1053.md) |
| Unknown | 74x1056 | 8-bit Schottky diode bus termination array, clamp to GND | [excluded](ttl_74xx/spec/chips/ttl_74x1056.md) |
| Unknown | 74x1071 | 10-bit bus termination array with bus-hold function | [implemented](ttl_74xx/spec/chips/ttl_74x1071.md) |
| Unknown | 74x1073 | 16-bit bus termination array with bus-hold function | [implemented](ttl_74xx/spec/chips/ttl_74x1073.md) |
| Unknown | 74x1074 | dual D negative edge triggered flip-flop, asynchronous preset and clear | [implemented](ttl_74xx/spec/chips/ttl_74x1074.md) |
| Unknown | 74x1181 | 4-bit arithmetic logic unit | [implemented](ttl_74xx/spec/chips/ttl_74x1181.md) |
| Unknown | 74x1240 | octal buffer / line driver, inverting (lower-power version of 74x240) | [implemented](ttl_74xx/spec/chips/ttl_74x1240.md) |
| Unknown | 74x1241 | octal buffer / line driver, non-inverting (lower-power version of 74x241) | [implemented](ttl_74xx/spec/chips/ttl_74x1241.md) |
| Unknown | 74x1242 | quad bus transceiver, inverting (lower-power version of 74x242) | [implemented](ttl_74xx/spec/chips/ttl_74x1242.md) |
| Unknown | 74x1243 | quad bus transceiver, non-inverting (lower-power version of 74x243) | [implemented](ttl_74xx/spec/chips/ttl_74x1243.md) |
| Unknown | 74x1244 | octal buffer / driver, non-inverting (lower-power version of 74x244) | [implemented](ttl_74xx/spec/chips/ttl_74x1244.md) |
| Unknown | 74x1245 | octal bus transceiver (lower-power version of 74x245) | [implemented](ttl_74xx/spec/chips/ttl_74x1245.md) |
| Unknown | 74x1280 | 9-bit parity generator/checker with registered outputs | [implemented](ttl_74xx/spec/chips/ttl_74x1280.md) |
| Unknown | 74x1284 | parallel printer interface transceiver / buffer (IEEE 1284) | [implemented](ttl_74xx/spec/chips/ttl_74x1284.md) |
| Unknown | 74x1394 | 2-bit GTLP transceiver with split LV-TTL port | [implemented](ttl_74xx/spec/chips/ttl_74x1394.md) |
| Unknown | 74x1395 | Dual 1-bit GTLP transceiver with split LV-TTL port | [implemented](ttl_74xx/spec/chips/ttl_74x1395.md) |
| Unknown | 74x1403 | 8-bit bus receiver plus 4-bit bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x1403.md) |
| Unknown | 74x1404 | oscillator driver | [excluded](ttl_74xx/spec/chips/ttl_74x1404.md) |
| Unknown | 74x1604 | dual 8-bit transparent latch with output multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x1604.md) |
| Unknown | 74x1612 | 18-bit LV-TTL-to-GTLP adjustable-edge-rate universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x1612.md) |
| Unknown | 74x1620 | octal bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x1620.md) |
| Unknown | 74x1621 | octal bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x1621.md) |
| Unknown | 74x1622 | octal bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x1622.md) |
| Unknown | 74x1623 | octal bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x1623.md) |
| Unknown | 74x1627 | 18-bit LV-TTL-to-GTLP adjustable-edge-rate bus transceiver with source synchronous clock outputs | [implemented](ttl_74xx/spec/chips/ttl_74x1627.md) |
| Unknown | 74x1631 | quad bus driver with complementary outputs | [pending](ttl_74xx/spec/chips/ttl_74x1631.md) |
| Unknown | 74x1638 | octal bus transceiver, inverting (lower-power version of 74x638) | [implemented](ttl_74xx/spec/chips/ttl_74x1638.md) |
| Unknown | 74x1639 | octal bus transceiver, non-inverting (lower-power version of 74x639) | [implemented](ttl_74xx/spec/chips/ttl_74x1639.md) |
| Unknown | 74x1640 | octal bus transceiver, inverting (lower-power version of 74x640) | [implemented](ttl_74xx/spec/chips/ttl_74x1640.md) |
| Unknown | 74x1641 | octal bus transceiver, non-inverting (lower-power version of 74x641) | [implemented](ttl_74xx/spec/chips/ttl_74x1641.md) |
| Unknown | 74x1642 | octal bus transceiver, inverting (lower-power version of 74x642) | [implemented](ttl_74xx/spec/chips/ttl_74x1642.md) |
| Unknown | 74x1643 | octal bus transceiver, inverting and non-inverting (lower-power version of 74x643) | [implemented](ttl_74xx/spec/chips/ttl_74x1643.md) |
| Unknown | 74x1644 | octal bus transceiver, inverting and non-inverting (lower-power version of 74x644) | [implemented](ttl_74xx/spec/chips/ttl_74x1644.md) |
| Unknown | 74x1650 | dual 9-bit Futurebus universal storage transceiver with split TTL I/O | [pending](ttl_74xx/spec/chips/ttl_74x1650.md) |
| Unknown | 74x1651 | 9-bit and 8-bit Futurebus universal storage transceivers with delayed buffered clock with split TTL I/O | [pending](ttl_74xx/spec/chips/ttl_74x1651.md) |
| Unknown | 74x1653 | 9-bit and 8-bit Futurebus universal storage transceivers with delayed buffered clock with split 3.3V TTL I/O | [pending](ttl_74xx/spec/chips/ttl_74x1653.md) |
| Unknown | 74x1655 | dual 8-bit GTL universal storage transceivers with live insertion | [pending](ttl_74xx/spec/chips/ttl_74x1655.md) |
| Unknown | 74x1760 | 10-bit 4-way latched address multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x1760.md) |
| Unknown | 74x1761 | dRAM and interrupt vector controller | [pending](ttl_74xx/spec/chips/ttl_74x1761.md) |
| Unknown | 74x1762 | dRAM address controller | [implemented](ttl_74xx/spec/chips/ttl_74x1762.md) |
| Unknown | 74x1763 | single-port dRAM controller | [pending](ttl_74xx/spec/chips/ttl_74x1763.md) |
| Unknown | 74x1764 | dual-port dRAM controller | [pending](ttl_74xx/spec/chips/ttl_74x1764.md) |
| Unknown | 74x1765 | dual-port dRAM controller with address latch | [pending](ttl_74xx/spec/chips/ttl_74x1765.md) |
| Unknown | 74x1766 | burst mode dRAM controller | [pending](ttl_74xx/spec/chips/ttl_74x1766.md) |
| Unknown | 74x1779 | 8-bit bidirectional binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x1779.md) |
| Unknown | 74x1801 | FM, MFM, and DM encoder / decoder, data rates up to 10 MHz | [pending](ttl_74xx/spec/chips/ttl_74x1801.md) |
| Unknown | 74x1802 | SerDes with ECC and CRC, data rates up to 10 MHz | [pending](ttl_74xx/spec/chips/ttl_74x1802.md) |
| Unknown | 74x1803 | quad clock driver | [implemented](ttl_74xx/spec/chips/ttl_74x1803.md) |
| Unknown | 74x1804 | hex 2-input NAND | [implemented](ttl_74xx/spec/chips/ttl_74x1804.md) |
| Unknown | 74x1805 | hex 2-input NOR | [implemented](ttl_74xx/spec/chips/ttl_74x1805.md) |
| Unknown | 74x1808 | hex 2-input AND | [implemented](ttl_74xx/spec/chips/ttl_74x1808.md) |
| Unknown | 74x1811 | FM, MFM, and DM encoder / decoder, data rates up to 20 MHz | [pending](ttl_74xx/spec/chips/ttl_74x1811.md) |
| Unknown | 74x1812 | SerDes with ECC and CRC, data rates up to 30 MHz | [pending](ttl_74xx/spec/chips/ttl_74x1812.md) |
| Unknown | 74x1821 | 10-bit bus interface flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x1821.md) |
| Unknown | 74x1823 | 9-bit bus interface flip-flops with clear | [implemented](ttl_74xx/spec/chips/ttl_74x1823.md) |
| Unknown | 74x1832 | hex 2-input OR | [implemented](ttl_74xx/spec/chips/ttl_74x1832.md) |
| Unknown | 74x1841 | 10-bit bus interface transparent latches | [implemented](ttl_74xx/spec/chips/ttl_74x1841.md) |
| Unknown | 74x1843 | 9-bit bus interface transparent latches with clear | [implemented](ttl_74xx/spec/chips/ttl_74x1843.md) |
| Unknown | 74x2000 | direction discriminator with microprocessor interface | [pending](ttl_74xx/spec/chips/ttl_74x2000.md) |
| Unknown | 74x2003 | 8-bit level translator | [implemented](ttl_74xx/spec/chips/ttl_74x2003.md) |
| Unknown | 74x2006 | 13-bit GTL to 3.3V TTL level translator | [implemented](ttl_74xx/spec/chips/ttl_74x2006.md) |
| Unknown | 74x2007 | 12-bit GTL to 3.3V TTL level translator | [implemented](ttl_74xx/spec/chips/ttl_74x2007.md) |
| Unknown | 74x2010 | 10-bit level translator | [implemented](ttl_74xx/spec/chips/ttl_74x2010.md) |
| Unknown | 74x2014 | 4-bit GTL to TTL transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x2014.md) |
| Unknown | 74x2031 | 9-bit Futurebus address/data transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x2031.md) |
| Unknown | 74x2032 | 9-bit Futurebus competition transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x2032.md) |
| Unknown | 74x2034 | 8-bit GTLP adjustable-edge-rate registered transceiver with split LV-TTL I/O | [pending](ttl_74xx/spec/chips/ttl_74x2034.md) |
| Unknown | 74x2040 | 8-bit Futurebus transceiver with split TTL I/O | [implemented](ttl_74xx/spec/chips/ttl_74x2040.md) |
| Unknown | 74x2041 | 7-bit Futurebus transceiver with split TTL I/O | [implemented](ttl_74xx/spec/chips/ttl_74x2041.md) |
| Unknown | 74x2107 | 12-bit GTL to 3.3V TTL level translator | [implemented](ttl_74xx/spec/chips/ttl_74x2107.md) |
| Unknown | 74x2125 | quad bus buffer | [implemented](ttl_74xx/spec/chips/ttl_74x2125.md) |
| Unknown | 74x2140 | 8k x 18 cache data RAM | [implemented](ttl_74xx/spec/chips/ttl_74x2140.md) |
| Unknown | 74x2150 | 512 x 8 cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2150.md) |
| Unknown | 74x2152 | 2k x 8 cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2152.md) |
| Unknown | 74x2154 | 2k x 8 cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2154.md) |
| Unknown | 74x2155 | 2k x 8 burst cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2155.md) |
| Unknown | 74x2156 | 16k x 4 burst cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2156.md) |
| Unknown | 74x2158 | 8k x 9 cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2158.md) |
| Unknown | 74x2159 | 8k x 9 cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2159.md) |
| Unknown | 74x2160 | 8k x 4 2-way cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2160.md) |
| Unknown | 74x2161 | synchronous presettable 4-bit binary counter, asynchronous clear | [implemented](ttl_74xx/spec/chips/ttl_74x2161.md) |
| Unknown | 74x2164 | 16k x 5 cache address comparator | [pending](ttl_74xx/spec/chips/ttl_74x2164.md) |
| Unknown | 74x2166 | 16k x 5 cache address comparator with input latches | [pending](ttl_74xx/spec/chips/ttl_74x2166.md) |
| Unknown | 74x2191 | synchronous presettable 4-bit binary up/down counter, up/down direction pin | [implemented](ttl_74xx/spec/chips/ttl_74x2191.md) |
| Unknown | 74x2193 | synchronous presettable 4-bit binary counter, separate up/down clocks | [implemented](ttl_74xx/spec/chips/ttl_74x2193.md) |
| Unknown | 74x2226 | dual 64-bit FIFO memories (64x1) | [implemented](ttl_74xx/spec/chips/ttl_74x2226.md) |
| Unknown | 74x2227 | dual 64-bit FIFO memories (64x1) | [implemented](ttl_74xx/spec/chips/ttl_74x2227.md) |
| Unknown | 74x2228 | dual 256-bit FIFO memories (256x1) | [implemented](ttl_74xx/spec/chips/ttl_74x2228.md) |
| Unknown | 74x2229 | dual 256-bit FIFO memories (256x1) | [implemented](ttl_74xx/spec/chips/ttl_74x2229.md) |
| Unknown | 74x2232 | 512-bit FIFO memory (64x8) | [implemented](ttl_74xx/spec/chips/ttl_74x2232.md) |
| Unknown | 74x2233 | 576-bit FIFO memory (64x9) | [implemented](ttl_74xx/spec/chips/ttl_74x2233.md) |
| Unknown | 74x2235 | 18432-bit bidirectional FIFO memory (2x1024x9) | [implemented](ttl_74xx/spec/chips/ttl_74x2235.md) |
| Unknown | 74x2236 | 18432-bit bidirectional FIFO memory (2x1024x9) | [implemented](ttl_74xx/spec/chips/ttl_74x2236.md) |
| Unknown | 74x2238 | 576-bit bidirectional FIFO memory (2x32x9) | [implemented](ttl_74xx/spec/chips/ttl_74x2238.md) |
| Unknown | 74x2240 | dual 4-bit bidirectional buffer / line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2240.md) |
| Unknown | 74x2241 | dual 4-bit bidirectional buffer / line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2241.md) |
| Unknown | 74x2242 | 4-bit bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2242.md) |
| Unknown | 74x2243 | 4-bit bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2243.md) |
| Unknown | 74x2244 | dual 4-bit buffer / line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2244.md) |
| Unknown | 74x2245 | octal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x2245.md) |
| Unknown | 74x2253 | dual 4-line to 1-line multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x2253.md) |
| Unknown | 74x2257 | quad 2-line to 1-line multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x2257.md) |
| Unknown | 74x2273 | octal D-type flip-flop, shared clock and clear | [implemented](ttl_74xx/spec/chips/ttl_74x2273.md) |
| Unknown | 74x2299 | 8-bit universal shift register | [implemented](ttl_74xx/spec/chips/ttl_74x2299.md) |
| Unknown | 74x2323 | dual line receiver | [implemented](ttl_74xx/spec/chips/ttl_74x2323.md) |
| Unknown | 74x2373 | 8-bit transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x2373.md) |
| Unknown | 74x2374 | octal D-type flip-flop, shared clock | [implemented](ttl_74xx/spec/chips/ttl_74x2374.md) |
| Unknown | 74x2377 | 8-bit register, clock enable | [implemented](ttl_74xx/spec/chips/ttl_74x2377.md) |
| Unknown | 74x2400 | dual 4-bit buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2400.md) |
| Unknown | 74x2410 | 11-bit MOS memory driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2410.md) |
| Unknown | 74x2411 | 11-bit MOS memory driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2411.md) |
| Unknown | 74x2414 | dual 2-to-4 line decoder with supply voltage monitor | [implemented](ttl_74xx/spec/chips/ttl_74x2414.md) |
| Unknown | 74x2420 | 16-bit NuBus address/data transceiver and register | [pending](ttl_74xx/spec/chips/ttl_74x2420.md) |
| Unknown | 74x2423 | 16-bit latched multiplexer/demultiplexer NuBus transceiver, inverting | [pending](ttl_74xx/spec/chips/ttl_74x2423.md) |
| Unknown | 74x2424 | 16-bit latched multiplexer/demultiplexer NuBus transceiver, non-inverting | [pending](ttl_74xx/spec/chips/ttl_74x2424.md) |
| Unknown | 74x2425 | Macintosh Coprocessor Platform NuBus address/data registered transceiver | [pending](ttl_74xx/spec/chips/ttl_74x2425.md) |
| Unknown | 74x2440 | NuBus interface controller | [pending](ttl_74xx/spec/chips/ttl_74x2440.md) |
| Unknown | 74x2441 | NuBus interface controller | [pending](ttl_74xx/spec/chips/ttl_74x2441.md) |
| Unknown | 74x2442 | NuBus block slave address generator | [pending](ttl_74xx/spec/chips/ttl_74x2442.md) |
| Unknown | 74x2509 | 9-output clock driver with PLL | [excluded](ttl_74xx/spec/chips/ttl_74x2509.md) |
| Unknown | 74x2510 | 10-output clock driver with PLL | [excluded](ttl_74xx/spec/chips/ttl_74x2510.md) |
| Unknown | 74x2525 | 8-output clock driver | [implemented](ttl_74xx/spec/chips/ttl_74x2525.md) |
| Unknown | 74x2526 | 8-output clock driver with input multiplexer | [pending](ttl_74xx/spec/chips/ttl_74x2526.md) |
| Unknown | 74x2533 | 8-bit bus interface latch, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2533.md) |
| Unknown | 74x2534 | 8-bit bus interface register, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2534.md) |
| Unknown | 74x2540 | 8-bit buffer / line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2540.md) |
| Unknown | 74x2541 | 8-bit buffer / line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2541.md) |
| Unknown | 74x2543 | 8-bit latched transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2543.md) |
| Unknown | 74x2544 | 8-bit latched transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2544.md) |
| Unknown | 74x2573 | 8-bit transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x2573.md) |
| Unknown | 74x2574 | octal D-type flip-flop, shared clock | [implemented](ttl_74xx/spec/chips/ttl_74x2574.md) |
| Unknown | 74x2620 | octal bus transceiver / MOS driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2620.md) |
| Unknown | 74x2623 | octal bus transceiver / MOS driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2623.md) |
| Unknown | 74x2640 | octal bus transceiver / MOS driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2640.md) |
| Unknown | 74x2643 | octal bus transceiver, mix of inverting and non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x2643.md) |
| Unknown | 74x2645 | octal bus transceiver / MOS driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2645.md) |
| Unknown | 74x2646 | octal registered transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2646.md) |
| Unknown | 74x2648 | octal registered transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2648.md) |
| Unknown | 74x2651 | octal registered transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2651.md) |
| Unknown | 74x2652 | octal registered transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2652.md) |
| Unknown | 74S2708 | 8192-bit PROM (1024x8) | [implemented](ttl_74xx/spec/chips/ttl_74s2708.md) |
| Unknown | 74x2725 | 4608-bit FIFO memory (512x9) | [implemented](ttl_74xx/spec/chips/ttl_74x2725.md) |
| Unknown | 74x2726 | 4608-bit bidirectional FIFO memory (512x9) | [implemented](ttl_74xx/spec/chips/ttl_74x2726.md) |
| Unknown | 74x2821 | 10-bit D-type flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x2821.md) |
| Unknown | 74x2823 | 9-bit D-type flip-flop with clear | [implemented](ttl_74xx/spec/chips/ttl_74x2823.md) |
| Unknown | 74x2825 | 8-bit D-type flip-flop with clear and clock enable | [implemented](ttl_74xx/spec/chips/ttl_74x2825.md) |
| Unknown | 74x2827 | 10-bit buffer, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2827.md) |
| Unknown | 74x2828 | 10-bit buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2828.md) |
| Unknown | 74x2833 | 8-bit bus transceiver with parity error flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x2833.md) |
| Unknown | 74x2841 | 10-bit transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x2841.md) |
| Unknown | 74x2843 | 9-bit transparent latch with asynchronous reset | [implemented](ttl_74xx/spec/chips/ttl_74x2843.md) |
| Unknown | 74x2845 | 8-bit transparent latch with asynchronous reset and multiple output enable | [implemented](ttl_74xx/spec/chips/ttl_74x2845.md) |
| Unknown | 74x2853 | 8-bit bus transceiver with parity error latch | [implemented](ttl_74xx/spec/chips/ttl_74x2853.md) |
| Unknown | 74x2861 | 10-bit non-inverting bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x2861.md) |
| Unknown | 74x2862 | 10-bit inverting bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x2862.md) |
| Unknown | 74x2863 | 9-bit non-inverting bus transceiver with dual output enable | [implemented](ttl_74xx/spec/chips/ttl_74x2863.md) |
| Unknown | 74x2864 | 9-bit inverting bus transceiver with dual output enable | [implemented](ttl_74xx/spec/chips/ttl_74x2864.md) |
| Unknown | 74x2952 | octal bus transceiver and register, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2952.md) |
| Unknown | 74x2953 | octal bus transceiver and register, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x2953.md) |
| Unknown | 74x2960 | error detection and correction (EDAC), equivalent to Am2960 | [pending](ttl_74xx/spec/chips/ttl_74x2960.md) |
| Unknown | 74x2961 | 4-bit EDAC bus buffer, inverting, equivalent to Am2961 | [implemented](ttl_74xx/spec/chips/ttl_74x2961.md) |
| Unknown | 74x2962 | 4-bit EDAC bus buffer, non-inverting, equivalent to Am2962 | [implemented](ttl_74xx/spec/chips/ttl_74x2962.md) |
| Unknown | 74x2967 | controller/driver for 16k/64k/256k dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x2967.md) |
| Unknown | 74x2968 | controller/driver for 16k/64k/256k dRAM | [implemented](ttl_74xx/spec/chips/ttl_74x2968.md) |
| Unknown | 74x2969 | memory timing controller for use with EDAC | [pending](ttl_74xx/spec/chips/ttl_74x2969.md) |
| Unknown | 74x2970 | memory timing controller for use without EDAC | [pending](ttl_74xx/spec/chips/ttl_74x2970.md) |
| Unknown | 74x3004 | selectable GTL voltage reference | [excluded](ttl_74xx/spec/chips/ttl_74x3004.md) |
| Unknown | 74x3037 | quad 2-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x3037.md) |
| Unknown | 74x3038 | quad 2-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x3038.md) |
| Unknown | 74x3040 | dual 4-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x3040.md) |
| Unknown | 74x3125 | quad FET bus switch, output enable active low | [implemented](ttl_74xx/spec/chips/ttl_74x3125.md) |
| Unknown | 74x3126 | quad FET bus switch, output enable active high | [implemented](ttl_74xx/spec/chips/ttl_74x3126.md) |
| Unknown | 74x3251 | 8-line to 1-line FET multiplexer / demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x3251.md) |
| Unknown | 74x3253 | dual 4-line to 1-line FET multiplexer / demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x3253.md) |
| Unknown | 74x3257 | quad 2-line to 1-line FET multiplexer / demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x3257.md) |
| Unknown | 74x3283 | 32-bit latchable transceiver with parity checker / generator | [implemented](ttl_74xx/spec/chips/ttl_74x3283.md) |
| Unknown | 74x3284 | 18-bit synchronous datapath multiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x3284.md) |
| Unknown | 74x3305 | dual FET bus switch with extended voltage range | [implemented](ttl_74xx/spec/chips/ttl_74x3305.md) |
| Unknown | 74x3306 | dual FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x3306.md) |
| Unknown | 74x3345 | octal FET bus switch, dual output enable | [implemented](ttl_74xx/spec/chips/ttl_74x3345.md) |
| Unknown | 74x3374 | 8-bit metastable-resistant D-type flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x3374.md) |
| Unknown | 74x3383 | 5-bit 4-port FET bus exchange switch | [implemented](ttl_74xx/spec/chips/ttl_74x3383.md) |
| Unknown | 74x3384 | dual 5-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x3384.md) |
| Unknown | 74x3386 | 5-bit 4-port FET bus exchange switch with extended voltage range | [implemented](ttl_74xx/spec/chips/ttl_74x3386.md) |
| Unknown | 74x3390 | octal 2-line to 1-line FET multiplexer / bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x3390.md) |
| Unknown | 74x3573 | octal transparent latch | [implemented](ttl_74xx/spec/chips/ttl_74x3573.md) |
| Unknown | 74x3574 | octal D-type flip flop | [implemented](ttl_74xx/spec/chips/ttl_74x3574.md) |
| Unknown | 74x3584 | dual 5-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x3584.md) |
| Unknown | 74x3611 | 2304-bit FIFO memory (64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3611.md) |
| Unknown | 74x3612 | 4608-bit bidirectional FIFO memory (2x64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3612.md) |
| Unknown | 74x3613 | 2304-bit FIFO memory (64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3613.md) |
| Unknown | 74x3614 | 4608-bit bidirectional FIFO memory (2x64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3614.md) |
| Unknown | 74x3622 | 18432-bit bidirectional FIFO memory (2x256x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3622.md) |
| Unknown | 74x3631 | 18432-bit FIFO memory (512x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3631.md) |
| Unknown | 74x3632 | 36864-bit bidirectional FIFO memory (2x512x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3632.md) |
| Unknown | 74x3638 | 32768-bit bidirectional FIFO memory (2x512x32) | [implemented](ttl_74xx/spec/chips/ttl_74x3638.md) |
| Unknown | 74x3641 | 36864-bit FIFO memory (1024x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3641.md) |
| Unknown | 74x3642 | 73728-bit bidirectional FIFO memory (2x1024x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3642.md) |
| Unknown | 74x3651 | 73728-bit FIFO memory (2048x36) | [implemented](ttl_74xx/spec/chips/ttl_74x3651.md) |
| Unknown | 74x3708 | 8192-bit PROM (1024x8) | [implemented](ttl_74xx/spec/chips/ttl_74x3708.md) |
| Unknown | 74x3807 | 1-to-10 clock driver | [implemented](ttl_74xx/spec/chips/ttl_74x3807.md) |
| Unknown | 74x3827 | 10-bit buffer | [implemented](ttl_74xx/spec/chips/ttl_74x3827.md) |
| Unknown | 74x3861 | 10-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x3861.md) |
| Unknown | 74x3862 | 10-bit FET bus switch with dual output enable | [implemented](ttl_74xx/spec/chips/ttl_74x3862.md) |
| Unknown | 74x3893 | quad Futurebus backplane transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x3893.md) |
| Unknown | 74x3907 | Pentium clock synthesizer | [pending](ttl_74xx/spec/chips/ttl_74x3907.md) |
| Unknown | 74x3932 | PLL-based clock driver | [excluded](ttl_74xx/spec/chips/ttl_74x3932.md) |
| Unknown | 74x4002 | dual 4-input NOR gate | [implemented](ttl_74xx/spec/chips/ttl_74x4002.md) |
| Unknown | 74x4015 | dual 4-bit shift registers | [implemented](ttl_74xx/spec/chips/ttl_74x4015.md) |
| Unknown | 74x4016 | quad bilateral switch | [excluded](ttl_74xx/spec/chips/ttl_74x4016.md) |
| Unknown | 74x4017 | 5-stage ÷10 Johnson counter | [implemented](ttl_74xx/spec/chips/ttl_74x4017.md) |
| Unknown | 74x4020 | 14-stage binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x4020.md) |
| Unknown | 74x4022 | 4-stage ÷8 Johnson counter | [implemented](ttl_74xx/spec/chips/ttl_74x4022.md) |
| Unknown | 74x4024 | 7-stage ripple carry binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x4024.md) |
| Unknown | 74x4028 | BCD to decimal decoder | [implemented](ttl_74xx/spec/chips/ttl_74x4028.md) |
| Unknown | 74x4040 | 12-stage binary ripple counter | [implemented](ttl_74xx/spec/chips/ttl_74x4040.md) |
| Unknown | 74x4046 | phase-locked loop and voltage-controlled oscillator | [excluded](ttl_74xx/spec/chips/ttl_74x4046.md) |
| Unknown | 74x4049 | hex inverting buffer | [implemented](ttl_74xx/spec/chips/ttl_74x4049.md) |
| Unknown | 74x4050 | hex buffer/converter (non-inverting) | [implemented](ttl_74xx/spec/chips/ttl_74x4050.md) |
| Unknown | 74x4051 | high-speed 8-channel analog multiplexer/demultiplexer | [excluded](ttl_74xx/spec/chips/ttl_74x4051.md) |
| Unknown | 74x4052 | dual 4-channel analog multiplexer/demultiplexers | [excluded](ttl_74xx/spec/chips/ttl_74x4052.md) |
| Unknown | 74x4053 | triple 2-channel analog multiplexer/demultiplexers | [excluded](ttl_74xx/spec/chips/ttl_74x4053.md) |
| Unknown | 74x4059 | programmable divide-by-N counter | [implemented](ttl_74xx/spec/chips/ttl_74x4059.md) |
| Unknown | 74x4060 | 14-stage binary ripple counter with oscillator | [implemented](ttl_74xx/spec/chips/ttl_74x4060.md) |
| Unknown | 74x4061 | 14-stage asynchronous binary counter with oscillator | [pending](ttl_74xx/spec/chips/ttl_74x4061.md) |
| Unknown | 74x4066 | quad single-pole single-throw analog switch | [excluded](ttl_74xx/spec/chips/ttl_74x4066.md) |
| Unknown | 74x4067 | 16-channel analog multiplexer/demultiplexer | [excluded](ttl_74xx/spec/chips/ttl_74x4067.md) |
| Unknown | 74x4072 | dual 4-input OR gate | [implemented](ttl_74xx/spec/chips/ttl_74x4072.md) |
| Unknown | 74x4075 | triple 3-input OR gate | [implemented](ttl_74xx/spec/chips/ttl_74x4075.md) |
| Unknown | 74x4078 | single 8-input OR/NOR gate | [implemented](ttl_74xx/spec/chips/ttl_74x4078.md) |
| Unknown | 74x4094 | 8-bit three-state shift register/latch | [implemented](ttl_74xx/spec/chips/ttl_74x4094.md) |
| Unknown | 74x4102 | 2-digit BCD presettable synchronous down counter | [implemented](ttl_74xx/spec/chips/ttl_74x4102.md) |
| Unknown | 74x4103 | 8-bit binary presettable synchronous down counter | [implemented](ttl_74xx/spec/chips/ttl_74x4103.md) |
| Unknown | 74x4245 | 8-bit 3V/5V translating transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x4245.md) |
| Unknown | 74x4301 | 8-bit latch, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x4301.md) |
| Unknown | 74x4302 | 8-bit latch, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x4302.md) |
| Unknown | 74x4303 | 8-bit D-type flip-flop, inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x4303.md) |
| Unknown | 74x4304 | 8-bit D-type flip-flop, non-inverting outputs | [implemented](ttl_74xx/spec/chips/ttl_74x4304.md) |
| Unknown | 74x4305 | dual 4-bit buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x4305.md) |
| Unknown | 74x4306 | dual 4-bit buffer, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x4306.md) |
| Unknown | 74x4316 | quad analog switch | [excluded](ttl_74xx/spec/chips/ttl_74x4316.md) |
| Unknown | 74x4351 | 8-channel analog multiplexer/demultiplexer with latch | [excluded](ttl_74xx/spec/chips/ttl_74x4351.md) |
| Unknown | 74x4352 | dual 4-channel analog multiplexer/demultiplexer with latch | [excluded](ttl_74xx/spec/chips/ttl_74x4352.md) |
| Unknown | 74x4353 | triple 2-channel analog multiplexer/demultiplexer with latch | [excluded](ttl_74xx/spec/chips/ttl_74x4353.md) |
| Unknown | 74x4374 | 8-bit dual-rank synchronizer | [implemented](ttl_74xx/spec/chips/ttl_74x4374.md) |
| Unknown | 74x4503 | controller for 64k/256k/1M dynamic RAM | [pending](ttl_74xx/spec/chips/ttl_74x4503.md) |
| Unknown | 74x4510 | BCD decade up/down counter | [implemented](ttl_74xx/spec/chips/ttl_74x4510.md) |
| Unknown | 74x4511 | BCD to 7-segment decoder | [implemented](ttl_74xx/spec/chips/ttl_74x4511.md) |
| Unknown | 74x4514 | 4-to-16 line decoder/demultiplexer, input latches | [implemented](ttl_74xx/spec/chips/ttl_74x4514.md) |
| Unknown | 74x4515 | 4-to-16 line decoder/demultiplexer with input latches; inverting | [implemented](ttl_74xx/spec/chips/ttl_74x4515.md) |
| Unknown | 74x4516 | 4-bit binary up/down counter | [implemented](ttl_74xx/spec/chips/ttl_74x4516.md) |
| Unknown | 74x4518 | dual 4-bit synchronous decade counter | [implemented](ttl_74xx/spec/chips/ttl_74x4518.md) |
| Unknown | 74x4520 | dual 4-bit synchronous binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x4520.md) |
| Unknown | 74x4538 | dual retriggerable precision monostable multivibrator | [excluded](ttl_74xx/spec/chips/ttl_74x4538.md) |
| Unknown | 74x4543 | BCD to 7-segment latch/decoder/driver for LCDs | [implemented](ttl_74xx/spec/chips/ttl_74x4543.md) |
| Unknown | 74x4560 | 4-bit BCD adder | [implemented](ttl_74xx/spec/chips/ttl_74x4560.md) |
| Unknown | 74x4724 | 8-bit addressable latch | [implemented](ttl_74xx/spec/chips/ttl_74x4724.md) |
| Unknown | 74x4764 | programmable dRAM controller | [pending](ttl_74xx/spec/chips/ttl_74x4764.md) |
| Unknown | 74x4799 | Timer for NiCd and NiMH chargers | [pending](ttl_74xx/spec/chips/ttl_74x4799.md) |
| Unknown | 74x4851 | 8-channel analog multiplexer/demultiplexer | [excluded](ttl_74xx/spec/chips/ttl_74x4851.md) |
| Unknown | 74x4852 | dual 4-channel analog multiplexer/demultiplexer | [excluded](ttl_74xx/spec/chips/ttl_74x4852.md) |
| Unknown | 74x5074 | dual positive edge-triggered D-type flip-flop (metastable immune) | [implemented](ttl_74xx/spec/chips/ttl_74x5074.md) |
| Unknown | 74x5245 | octal bidirectional transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x5245.md) |
| Unknown | 74x5300 | fiber optic LED driver | [excluded](ttl_74xx/spec/chips/ttl_74x5300.md) |
| Unknown | 74x5302 | dual fiber optic LED / clock driver | [excluded](ttl_74xx/spec/chips/ttl_74x5302.md) |
| Unknown | 74x5400 | 11-bit line/memory driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x5400.md) |
| Unknown | 74x5401 | 11-bit line/memory driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x5401.md) |
| Unknown | 74x5402 | 12-bit line/memory driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x5402.md) |
| Unknown | 74x5403 | 12-bit line/memory driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x5403.md) |
| Unknown | 74x5555 | programmable delay timer with oscillator | [pending](ttl_74xx/spec/chips/ttl_74x5555.md) |
| Unknown | 74x5620 | octal bidirectional transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x5620.md) |
| Unknown | 74x6000 | logic-to-logic optocoupler, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x6000.md) |
| Unknown | 74x6001 | logic-to-logic optocoupler, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x6001.md) |
| Unknown | 74x6010 | logic-to-logic optocoupler, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x6010.md) |
| Unknown | 74x6011 | logic-to-logic optocoupler, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x6011.md) |
| Unknown | 74x6300 | programmable dynamic memory refresh timer | [pending](ttl_74xx/spec/chips/ttl_74x6300.md) |
| Unknown | 74x6301 | dynamic memory refresh controller, transparent and burst modes, for 16K, 64K, 256K, and 1M dRAM | [pending](ttl_74xx/spec/chips/ttl_74x6301.md) |
| Unknown | 74x6302 | dynamic memory refresh controller, transparent and burst modes, for 16K, 64K, 256K, and 1M dRAM | [pending](ttl_74xx/spec/chips/ttl_74x6302.md) |
| Unknown | 74x6310 | static column and page mode access detector for dRAM | [pending](ttl_74xx/spec/chips/ttl_74x6310.md) |
| Unknown | 74x6311 | static column and page mode access detector for dRAM | [pending](ttl_74xx/spec/chips/ttl_74x6311.md) |
| Unknown | 74x6323 | programmable ripple counter with oscillator | [pending](ttl_74xx/spec/chips/ttl_74x6323.md) |
| Unknown | 74x6364 | 64-bit flow-through error detection and correction circuit | [pending](ttl_74xx/spec/chips/ttl_74x6364.md) |
| Unknown | 74x6800 | 10-bit FET bus switch with precharge | [implemented](ttl_74xx/spec/chips/ttl_74x6800.md) |
| Unknown | 74x6845 | 8-bit FET bus switch with precharge and extended voltage range | [implemented](ttl_74xx/spec/chips/ttl_74x6845.md) |
| Unknown | 74x7001 | quad 2-input AND gate | [implemented](ttl_74xx/spec/chips/ttl_74x7001.md) |
| Unknown | 74x7002 | quad 2-input NOR gate | [implemented](ttl_74xx/spec/chips/ttl_74x7002.md) |
| Unknown | 74x7003 | quad 2-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x7003.md) |
| Unknown | 74x7006 | two inverters, one 3-input NAND, one 4-input NAND, one 3-input NOR, one 4-input NOR | [implemented](ttl_74xx/spec/chips/ttl_74x7006.md) |
| Unknown | 74x7007 | hex buffer gate | [implemented](ttl_74xx/spec/chips/ttl_74x7007.md) |
| Unknown | 74x7008 | two inverters, three 2-input NAND, three 2-input NOR | [implemented](ttl_74xx/spec/chips/ttl_74x7008.md) |
| Unknown | 74x7014 | hex buffer gate | [implemented](ttl_74xx/spec/chips/ttl_74x7014.md) |
| Unknown | 74x7022 | 4-stage ÷8 Johnson counter with power-up clear | [implemented](ttl_74xx/spec/chips/ttl_74x7022.md) |
| Unknown | 74x7030 | 576-bit FIFO memory (64x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7030.md) |
| Unknown | 74x7032 | quad 2-input OR gates | [implemented](ttl_74xx/spec/chips/ttl_74x7032.md) |
| Unknown | 74x7038 | 9-bit bus transceiver with latch | [implemented](ttl_74xx/spec/chips/ttl_74x7038.md) |
| Unknown | 74x7046 | phase-locked loop with voltage-controlled oscillator and lock detector | [excluded](ttl_74xx/spec/chips/ttl_74x7046.md) |
| Unknown | 74x7060 | 14-stage binary counter with oscillator | [pending](ttl_74xx/spec/chips/ttl_74x7060.md) |
| Unknown | 74x7074 | two inverters, one 2-input NAND, one 2-input NOR, two D-type flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x7074.md) |
| Unknown | 74x7075 | two inverters, two 2-input NAND, two D-type flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x7075.md) |
| Unknown | 74x7076 | two inverters, two 2-input NOR, two D-type flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x7076.md) |
| Unknown | 74x7080 | 16-bit parity generator / checker | [implemented](ttl_74xx/spec/chips/ttl_74x7080.md) |
| Unknown | 74x7132 | quad adjustable comparator with output latches | [excluded](ttl_74xx/spec/chips/ttl_74x7132.md) |
| Unknown | 74x7200 | 2304-bit FIFO memory (256x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7200.md) |
| Unknown | 74x7201 | 4608-bit FIFO memory (512x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7201.md) |
| Unknown | 74x7202 | 9216-bit FIFO memory (1024x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7202.md) |
| Unknown | 74x7203 | 18432-bit FIFO memory (2048x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7203.md) |
| Unknown | 74x7205 | 73728-bit FIFO memory (8192x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7205.md) |
| Unknown | 74x7206 | 147456-bit FIFO memory (16384x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7206.md) |
| Unknown | 74x7240 | octal bus buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7240.md) |
| Unknown | 74x7241 | octal bus buffer, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7241.md) |
| Unknown | 74x7244 | octal bus buffer, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7244.md) |
| Unknown | 74x7245 | octal bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7245.md) |
| Unknown | 74x7266 | quad 2-input XNOR gate | [implemented](ttl_74xx/spec/chips/ttl_74x7266.md) |
| Unknown | 74x7273 | octal positive edge-triggered D-type flip-flop with reset | [implemented](ttl_74xx/spec/chips/ttl_74x7273.md) |
| Unknown | 74x7292 | programmable divider/timer | [implemented](ttl_74xx/spec/chips/ttl_74x7292.md) |
| Unknown | 74x7294 | programmable divider/timer | [implemented](ttl_74xx/spec/chips/ttl_74x7294.md) |
| Unknown | 74x7340 | 8-bit bus driver with bidirectional registers | [implemented](ttl_74xx/spec/chips/ttl_74x7340.md) |
| Unknown | 74x7403 | 256-bit FIFO memory (64x4) | [implemented](ttl_74xx/spec/chips/ttl_74x7403.md) |
| Unknown | 74x7404 | 320-bit FIFO memory (64x5) | [implemented](ttl_74xx/spec/chips/ttl_74x7404.md) |
| Unknown | 74x7540 | octal buffer/line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7540.md) |
| Unknown | 74x7541 | octal buffer/line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7541.md) |
| Unknown | 74x7597 | 8-bit shift register with input latches | [implemented](ttl_74xx/spec/chips/ttl_74x7597.md) |
| Unknown | 74x7623 | octal bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7623.md) |
| Unknown | 74x7640 | octal bus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7640.md) |
| Unknown | 74x7643 | octal bus transceiver, non-inverting/inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7643.md) |
| Unknown | 74x7645 | octal bus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x7645.md) |
| Unknown | 74x7731 | quad 64-bit static shift register | [implemented](ttl_74xx/spec/chips/ttl_74x7731.md) |
| Unknown | 74x7793 | 8-bit noninverting transparent latch with readback | [implemented](ttl_74xx/spec/chips/ttl_74x7793.md) |
| Unknown | 74x7801 | 18432-bit FIFO memory (1024x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7801.md) |
| Unknown | 74x7802 | 18432-bit FIFO memory (1024x18) | [implemented](ttl_74xx/spec/chips/ttl_74x7802.md) |
| Unknown | 74x7803 | 9216-bit FIFO memory (512x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7803.md) |
| Unknown | 74x7804 | 9216-bit FIFO memory (512x18) | [implemented](ttl_74xx/spec/chips/ttl_74x7804.md) |
| Unknown | 74x7805 | 4608-bit FIFO memory (256x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7805.md) |
| Unknown | 74x7806 | 4608-bit FIFO memory (256x18) | [implemented](ttl_74xx/spec/chips/ttl_74x7806.md) |
| Unknown | 74x7807 | 18432-bit FIFO memory (2048x9), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7807.md) |
| Unknown | 74x7808 | 18432-bit FIFO memory (2048x9) | [implemented](ttl_74xx/spec/chips/ttl_74x7808.md) |
| Unknown | 74x7811 | 18432-bit FIFO memory (1024x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7811.md) |
| Unknown | 74x7813 | 1152-bit FIFO memory (64x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7813.md) |
| Unknown | 74x7814 | 1152-bit FIFO memory (64x18) | [implemented](ttl_74xx/spec/chips/ttl_74x7814.md) |
| Unknown | 74x7815 | 4608-bit bidirectional FIFO memory(2x64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x7815.md) |
| Unknown | 74x7816 | 4608-bit bidirectional FIFO memory(2x64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x7816.md) |
| Unknown | 74x7817 | 2304-bit FIFO memory(64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x7817.md) |
| Unknown | 74x7818 | 2304-bit FIFO memory(64x36) | [implemented](ttl_74xx/spec/chips/ttl_74x7818.md) |
| Unknown | 74x7819 | 18432-bit bidirectional FIFO memory (2x512x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7819.md) |
| Unknown | 74x7820 | 18432-bit bidirectional FIFO memory (2x512x18) | [implemented](ttl_74xx/spec/chips/ttl_74x7820.md) |
| Unknown | 74x7821 | 32768-bit bidirectional FIFO memory (2x512x32) | [implemented](ttl_74xx/spec/chips/ttl_74x7821.md) |
| Unknown | 74x7822 | 32768-bit bidirectional FIFO memory (2x512x32), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7822.md) |
| Unknown | 74x7823 | 36864-bit FIFO memory (1024x36), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7823.md) |
| Unknown | 74x7881 | 18432-bit FIFO memory (1024x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7881.md) |
| Unknown | 74x7882 | 36864-bit FIFO memory (2048x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7882.md) |
| Unknown | 74x7884 | 73728-bit FIFO memory (4096x18), clocked | [implemented](ttl_74xx/spec/chips/ttl_74x7884.md) |
| Unknown | 74x8003 | dual 2-input NAND gate | [implemented](ttl_74xx/spec/chips/ttl_74x8003.md) |
| Unknown | 74x8151 | 10-bit inverting/non-inverting buffer | [implemented](ttl_74xx/spec/chips/ttl_74x8151.md) |
| Unknown | 74x8153 | 8-bit serial-to-parallel interface | [implemented](ttl_74xx/spec/chips/ttl_74x8153.md) |
| Unknown | 74x8154 | dual 16-bit counters with output registers | [implemented](ttl_74xx/spec/chips/ttl_74x8154.md) |
| Unknown | 74x8161 | 8-bit synchronous binary counter | [implemented](ttl_74xx/spec/chips/ttl_74x8161.md) |
| Unknown | 74x8240 | octal inverting buffer with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8240.md) |
| Unknown | 74x8244 | octal non-inverting buffer with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8244.md) |
| Unknown | 74x8245 | octal bus transceiver with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8245.md) |
| Unknown | 74x8373 | octal D-type latch with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8373.md) |
| Unknown | 74x8374 | octal D-type edge-triggered flip-flop with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8374.md) |
| Unknown | 74x8400 | expandable error checker / corrector | [pending](ttl_74xx/spec/chips/ttl_74x8400.md) |
| Unknown | 74x8541 | 8-bit buffer, selectable inverting/non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x8541.md) |
| Unknown | 74x8543 | octal registered bus transceiver with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8543.md) |
| Unknown | 74x8646 | octal bus transceiver and register with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8646.md) |
| Unknown | 74x8652 | octal bus transceiver and register with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8652.md) |
| Unknown | 74x8818 | 16-bit microprogram sequencer, cascadable | [pending](ttl_74xx/spec/chips/ttl_74x8818.md) |
| Unknown | 74x8832 | 32-bit registered ALU | [pending](ttl_74xx/spec/chips/ttl_74x8832.md) |
| Unknown | 74x8834 | 40-bit register file | [pending](ttl_74xx/spec/chips/ttl_74x8834.md) |
| Unknown | 74x8835 | 16-bit microprogram sequencer, cascadable | [pending](ttl_74xx/spec/chips/ttl_74x8835.md) |
| Unknown | 74x8836 | 32x32-bit multiplier/accumulator | [pending](ttl_74xx/spec/chips/ttl_74x8836.md) |
| Unknown | 74x8837 | 64-bit floating point unit | [pending](ttl_74xx/spec/chips/ttl_74x8837.md) |
| Unknown | 74x8838 | 64-bit barrel shifter | [implemented](ttl_74xx/spec/chips/ttl_74x8838.md) |
| Unknown | 74x8839 | 32-bit shuffle/exchange network | [pending](ttl_74xx/spec/chips/ttl_74x8839.md) |
| Unknown | 74x8840 | digital crossbar switch | [pending](ttl_74xx/spec/chips/ttl_74x8840.md) |
| Unknown | 74x8841 | digital crossbar switch | [pending](ttl_74xx/spec/chips/ttl_74x8841.md) |
| Unknown | 74x8847 | 64-bit floating point and integer unit | [pending](ttl_74xx/spec/chips/ttl_74x8847.md) |
| Unknown | 74x8867 | 32-bit vector processor unit | [pending](ttl_74xx/spec/chips/ttl_74x8867.md) |
| Unknown | 74x8952 | octal registered bus transceiver with JTAG port | [pending](ttl_74xx/spec/chips/ttl_74x8952.md) |
| Unknown | 74x8960 | 8-bit bidirectional latched FutureBus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x8960.md) |
| Unknown | 74x8961 | 8-bit bidirectional latched FutureBus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x8961.md) |
| Unknown | 74x8962 | 9-bit bidirectional latched FutureBus transceiver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x8962.md) |
| Unknown | 74x8963 | 9-bit bidirectional latched FutureBus transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x8963.md) |
| Unknown | 74x8965 | 9-bit bidirectional latched FutureBus transceiver, latch select | [implemented](ttl_74xx/spec/chips/ttl_74x8965.md) |
| Unknown | 74x8966 | 9-bit bidirectional latched FutureBus transceiver, idle arbitration request / output | [implemented](ttl_74xx/spec/chips/ttl_74x8966.md) |
| Unknown | 74x8980 | JTAG test access port master with 8-bit host interface | [pending](ttl_74xx/spec/chips/ttl_74x8980.md) |
| Unknown | 74x8986 | linkable, multidrop-addressable JTAG transceiver | [pending](ttl_74xx/spec/chips/ttl_74x8986.md) |
| Unknown | 74x8990 | JTAG test access port master with 16-bit host interface | [pending](ttl_74xx/spec/chips/ttl_74x8990.md) |
| Unknown | 74x8994 | JTAG scan-controlled logic/signature analyzer | [pending](ttl_74xx/spec/chips/ttl_74x8994.md) |
| Unknown | 74x8996 | multidrop-addressable JTAG transceiver | [pending](ttl_74xx/spec/chips/ttl_74x8996.md) |
| Unknown | 74x8997 | scan-controlled JTAG concatenator | [pending](ttl_74xx/spec/chips/ttl_74x8997.md) |
| Unknown | 74x8999 | scan-controlled JTAG multiplexer | [pending](ttl_74xx/spec/chips/ttl_74x8999.md) |
| Unknown | 74x9000 | programmable timer with oscillator | [pending](ttl_74xx/spec/chips/ttl_74x9000.md) |
| Unknown | 74x9014 | nine-wide buffer/line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9014.md) |
| Unknown | 74x9015 | nine-wide buffer/line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9015.md) |
| Unknown | 74x9034 | nine-wide buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9034.md) |
| Unknown | 74x9035 | nine-wide buffer, noninverting | [implemented](ttl_74xx/spec/chips/ttl_74x9035.md) |
| Unknown | 74x9046 | PLL with band gap controlled VCO | [excluded](ttl_74xx/spec/chips/ttl_74x9046.md) |
| Unknown | 74x9114 | nine-wide inverter | [implemented](ttl_74xx/spec/chips/ttl_74x9114.md) |
| Unknown | 74x9115 | nine-wide buffer | [implemented](ttl_74xx/spec/chips/ttl_74x9115.md) |
| Unknown | 74x9134 | nine-wide buffer, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9134.md) |
| Unknown | 74x9135 | nine-wide buffer, noninverting | [implemented](ttl_74xx/spec/chips/ttl_74x9135.md) |
| Unknown | 74x9164 | 8-bit shift register (serial in/out, parallel in/out) | [implemented](ttl_74xx/spec/chips/ttl_74x9164.md) |
| Unknown | 74x9240 | 9-bit buffer / line driver, inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9240.md) |
| Unknown | 74x9244 | 9-bit buffer / line driver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9244.md) |
| Unknown | 74x9245 | 9-bit bidirectional transceiver, non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9245.md) |
| Unknown | 74x9323 | programmable ripple counter with oscillator | [pending](ttl_74xx/spec/chips/ttl_74x9323.md) |
| Unknown | 74x9510 | 16×16-bit multiplier/accumulator (compatible to Am29510 and TDC1010) | [pending](ttl_74xx/spec/chips/ttl_74x9510.md) |
| Unknown | 74x9541 | 8-bit buffer / line driver, inverting / non-inverting | [implemented](ttl_74xx/spec/chips/ttl_74x9541.md) |
| Unknown | 74x9595 | 8-bit shift register with latch (serial in, parallel out) | [implemented](ttl_74xx/spec/chips/ttl_74x9595.md) |
| Unknown | 74x40102 | presettable synchronous 2-decade BCD down counter | [implemented](ttl_74xx/spec/chips/ttl_74x40102.md) |
| Unknown | 74x40103 | presettable 8-bit synchronous down counter | [implemented](ttl_74xx/spec/chips/ttl_74x40103.md) |
| Unknown | 74x40104 | 4-bit bidirectional universal shift register | [implemented](ttl_74xx/spec/chips/ttl_74x40104.md) |
| Unknown | 74x40105 | 64-bit FIFO memory (16x4) | [implemented](ttl_74xx/spec/chips/ttl_74x40105.md) |
| Unknown | 74x1616 | 17-bit LVTTL-to-GTLP adjustable edge rate universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x1616.md) |
| Unknown | 74x1645 | 16-bit LVTTL-to-GTLP adjustable edge rate bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x1645.md) |
| Unknown | 74x16209 | 18-bit FET bus exchange switches | [implemented](ttl_74xx/spec/chips/ttl_74x16209.md) |
| Unknown | 74x16210 | 20-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x16210.md) |
| Unknown | 74x16211 | 24-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x16211.md) |
| Unknown | 74x16212 | 24-bit FET bus exchange switches | [implemented](ttl_74xx/spec/chips/ttl_74x16212.md) |
| Unknown | 74x16213 | 24-bit FET bus exchange switches | [implemented](ttl_74xx/spec/chips/ttl_74x16213.md) |
| Unknown | 74x16214 | 12-bit 1-of-3 FET multiplexer/demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x16214.md) |
| Unknown | 74x16222 | 22-bit voltage clamp | [excluded](ttl_74xx/spec/chips/ttl_74x16222.md) |
| Unknown | 74x16232 | synchronous 16-bit 1-of-2 FET multiplexer/demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x16232.md) |
| Unknown | 74x16233 | 16-bit 1-of-2 FET multiplexer/demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x16233.md) |
| Unknown | 74x16240 | 16-bit inverting buffer/driver with grouped 4-bit output enables (all active-low) | [implemented](ttl_74xx/spec/chips/ttl_74x16240.md) |
| Unknown | 74x16241 | 16-bit non-inverting buffer/driver with grouped 4-bit output enables (1 and 4 active-low) | [implemented](ttl_74xx/spec/chips/ttl_74x16241.md) |
| Unknown | 74x16244 | 16-bit non-inverting buffer/driver with grouped 4-bit output enables (all active-low) | [implemented](ttl_74xx/spec/chips/ttl_74x16244.md) |
| Unknown | 74x16245 | 16-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16245.md) |
| Unknown | 74x16246 | 11-bit incident wave switching bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16246.md) |
| Unknown | 74x16260 | 12-bit to 24-bit multiplexed D-type latches | [pending](ttl_74xx/spec/chips/ttl_74x16260.md) |
| Unknown | 74x16269 | 12-bit to 24-bit registered bus exchanger | [pending](ttl_74xx/spec/chips/ttl_74x16269.md) |
| Unknown | 74x16270 | 12-bit to 24-bit registered bus exchanger | [pending](ttl_74xx/spec/chips/ttl_74x16270.md) |
| Unknown | 74x16271 | 12-bit to 24-bit multiplexed bus exchanger | [pending](ttl_74xx/spec/chips/ttl_74x16271.md) |
| Unknown | 74x16282 | 18-bit to 36-bit registered bus exchanger | [pending](ttl_74xx/spec/chips/ttl_74x16282.md) |
| Unknown | 74x16292 | 12-bit 1-of-2 FET multiplexer/demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x16292.md) |
| Unknown | 74x16334 | 16-bit universal bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x16334.md) |
| Unknown | 74x16344 | 1-bit to 4-bit address driver | [implemented](ttl_74xx/spec/chips/ttl_74x16344.md) |
| Unknown | 74x16373 | 16-bit transparent D-type latches | [implemented](ttl_74xx/spec/chips/ttl_74x16373.md) |
| Unknown | 74x16374 | 16-bit edge-triggered D-type flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x16374.md) |
| Unknown | 74x16377 | 16-bit edge-triggered D-type flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x16377.md) |
| Unknown | 74x16390 | 16-bit to 32-bit FET multiplexer/demultiplexer bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x16390.md) |
| Unknown | 74x16409 | 9-bit 4-port universal bus exchanger | [pending](ttl_74xx/spec/chips/ttl_74x16409.md) |
| Unknown | 74x16460 | 4-to-1 multiplexed/demultiplexed registered transceiver | [pending](ttl_74xx/spec/chips/ttl_74x16460.md) |
| Unknown | 74x16470 | 16-bit registered transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16470.md) |
| Unknown | 74x16500 | 18-bit universal bus transceiver (registered, active low clock) | [implemented](ttl_74xx/spec/chips/ttl_74x16500.md) |
| Unknown | 74x16501 | 18-bit universal bus transceiver (registered, active high clock) | [implemented](ttl_74xx/spec/chips/ttl_74x16501.md) |
| Unknown | 74x16524 | 18-bit registered bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16524.md) |
| Unknown | 74x16525 | 18-bit registered bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16525.md) |
| Unknown | 74x16540 | 16-bit inverting buffer/driver with grouped 8-bit output enables (active-low) | [implemented](ttl_74xx/spec/chips/ttl_74x16540.md) |
| Unknown | 74x16541 | 16-bit non-inverting buffer/driver with grouped 8-bit output enables (active-low) | [implemented](ttl_74xx/spec/chips/ttl_74x16541.md) |
| Unknown | 74x16543 | 16-bit registered tranceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16543.md) |
| Unknown | 74x16600 | 18-bit universal bus transceiver (registered, active low clock) | [implemented](ttl_74xx/spec/chips/ttl_74x16600.md) |
| Unknown | 74x16601 | 18-bit universal bus transceiver (registered, active high clock) | [implemented](ttl_74xx/spec/chips/ttl_74x16601.md) |
| Unknown | 74x16612 | 18-bit LVTTL-to-GTL+ universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16612.md) |
| Unknown | 74x16616 | 17-bit LVTTL-to-GTL+ universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16616.md) |
| Unknown | 74x16620 | 16-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16620.md) |
| Unknown | 74x16622 | 18-bit LVTTL-to-GTL+ bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16622.md) |
| Unknown | 74x16623 | 16-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16623.md) |
| Unknown | 74x16640 | 16-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16640.md) |
| Unknown | 74x16646 | 16-bit bus transceiver and registers | [implemented](ttl_74xx/spec/chips/ttl_74x16646.md) |
| Unknown | 74x16648 | 16-bit bus transceiver and registers | [implemented](ttl_74xx/spec/chips/ttl_74x16648.md) |
| Unknown | 74x16651 | 16-bit bus transceiver and registers | [implemented](ttl_74xx/spec/chips/ttl_74x16651.md) |
| Unknown | 74x16652 | 16-bit bus transceiver and registers | [implemented](ttl_74xx/spec/chips/ttl_74x16652.md) |
| Unknown | 74x16657 | 16-bit bus transceiver with parity generators/checkers | [pending](ttl_74xx/spec/chips/ttl_74x16657.md) |
| Unknown | 74x16721 | 3.3-V 20-bit flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x16721.md) |
| Unknown | 74x16722 | 22-bit flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x16722.md) |
| Unknown | 74x16800 | 20-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x16800.md) |
| Unknown | 74x16811 | 24-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x16811.md) |
| Unknown | 74x16820 | 3.3-V 10-bit flip-flop with dual outputs | [implemented](ttl_74xx/spec/chips/ttl_74x16820.md) |
| Unknown | 74x16821 | 20-bit bus interface flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x16821.md) |
| Unknown | 74x16823 | 18-bit bus interface flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x16823.md) |
| Unknown | 74x16825 | 18-bit non-inverting bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x16825.md) |
| Unknown | 74x16826 | 18-bit inverting bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x16826.md) |
| Unknown | 74x16827 | 20-bit non-inverting bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x16827.md) |
| Unknown | 74x16828 | 20-bit inverting bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x16828.md) |
| Unknown | 74x16831 | 1-to-4 address register/driver | [pending](ttl_74xx/spec/chips/ttl_74x16831.md) |
| Unknown | 74x16832 | 1-to-4 address register/driver | [pending](ttl_74xx/spec/chips/ttl_74x16832.md) |
| Unknown | 74x16833 | dual 8-bit to 9-bit parity bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x16833.md) |
| Unknown | 74x16834 | 18-bit universal bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x16834.md) |
| Unknown | 74x16835 | 18-bit universal bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x16835.md) |
| Unknown | 74x16841 | 20-bit bus interface D-type latches | [implemented](ttl_74xx/spec/chips/ttl_74x16841.md) |
| Unknown | 74x16843 | 18-bit bus interface D-type latches | [implemented](ttl_74xx/spec/chips/ttl_74x16843.md) |
| Unknown | 74x16853 | dual 8-bit to 9-bit parity bus transceiver | [pending](ttl_74xx/spec/chips/ttl_74x16853.md) |
| Unknown | 74x16857 | 14-bit registered buffer | [implemented](ttl_74xx/spec/chips/ttl_74x16857.md) |
| Unknown | 74x16859 | 13-bit to 26-bit registered buffer | [implemented](ttl_74xx/spec/chips/ttl_74x16859.md) |
| Unknown | 74x16861 | 20-bit FET bus switch | [implemented](ttl_74xx/spec/chips/ttl_74x16861.md) |
| Unknown | 74x16863 | 18-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16863.md) |
| Unknown | 74x16901 | 18-bit universal bus transceiver with parity generators/checkers | [pending](ttl_74xx/spec/chips/ttl_74x16901.md) |
| Unknown | 74x16903 | 3.3-V 12-bit universal bus driver with parity checker | [pending](ttl_74xx/spec/chips/ttl_74x16903.md) |
| Unknown | 74x16912 | 18-bit LVTTL-to-GTLP universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16912.md) |
| Unknown | 74x16916 | 17-bit LVTTL-to-GTLP universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16916.md) |
| Unknown | 74x16923 | 18-bit LVTTL-to-GTLP universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16923.md) |
| Unknown | 74x16945 | 16-bit LVTTL-to-GTLP bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16945.md) |
| Unknown | 74x16952 | 16-bit registered transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x16952.md) |
| Unknown | 74x16973 | 8-bit bus transceiver and transparent D-type latch | [implemented](ttl_74xx/spec/chips/ttl_74x16973.md) |
| Unknown | 74x161284 | 19-bit bus interface | [implemented](ttl_74xx/spec/chips/ttl_74x161284.md) |
| Unknown | 74x162240 | 3.3-V ABT 16-bit buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x162240.md) |
| Unknown | 74x162241 | 3.3-V ABT 16-bit buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x162241.md) |
| Unknown | 74x162244 | 16-bit buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x162244.md) |
| Unknown | 74x162245 | 16-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x162245.md) |
| Unknown | 74x162260 | 12-bit to 24-bit multiplexed D-type latch | [implemented](ttl_74xx/spec/chips/ttl_74x162260.md) |
| Unknown | 74x162268 | 12-bit to 24-bit registered bus exchanger | [implemented](ttl_74xx/spec/chips/ttl_74x162268.md) |
| Unknown | 74x162280 | 16-bit to 32-bit registered bus exchanger with byte masks | [pending](ttl_74xx/spec/chips/ttl_74x162280.md) |
| Unknown | 74x162282 | 18-bit to 36-bit registered bus exchanger | [pending](ttl_74xx/spec/chips/ttl_74x162282.md) |
| Unknown | 74x162292 | 12-bit 1-of-2 FET multiplexer/demultiplexer | [implemented](ttl_74xx/spec/chips/ttl_74x162292.md) |
| Unknown | 74x162334 | 16-bit universal bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x162334.md) |
| Unknown | 74x162344 | 1-bit to 4-bit address driver | [implemented](ttl_74xx/spec/chips/ttl_74x162344.md) |
| Unknown | 74x162373 | 3.3-V ABT 16-bit transparent D-type latch | [implemented](ttl_74xx/spec/chips/ttl_74x162373.md) |
| Unknown | 74x162374 | 3.3-V ABT 16-bit edge triggered D-type flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x162374.md) |
| Unknown | 74x162460 | 4-to-1 multiplexed/demultiplexed registered transceiver | [pending](ttl_74xx/spec/chips/ttl_74x162460.md) |
| Unknown | 74x162500 | 18-bit universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x162500.md) |
| Unknown | 74x162501 | 18-bit registered transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x162501.md) |
| Unknown | 74x162525 | 18-bit registered bus transceiver | [pending](ttl_74xx/spec/chips/ttl_74x162525.md) |
| Unknown | 74x162541 | 3.3-V ABT 16-bit buffers/drivers | [implemented](ttl_74xx/spec/chips/ttl_74x162541.md) |
| Unknown | 74x162543 | 16-bit latched transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x162543.md) |
| Unknown | 74x162601 | 18-bit universal bus tranceiver | [implemented](ttl_74xx/spec/chips/ttl_74x162601.md) |
| Unknown | 74x162646 | 16-bit registered transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x162646.md) |
| Unknown | 74x162652 | 16-bit registered transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x162652.md) |
| Unknown | 74x162721 | 3.3-V 20-bit flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x162721.md) |
| Unknown | 74x162820 | 3.3-V 10-bit flip-flop | [implemented](ttl_74xx/spec/chips/ttl_74x162820.md) |
| Unknown | 74x162821 | 20-bit bus interface flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x162821.md) |
| Unknown | 74x162823 | 18-bit bus interface flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x162823.md) |
| Unknown | 74x162825 | 18-bit buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x162825.md) |
| Unknown | 74x162827 | 20-bit buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x162827.md) |
| Unknown | 74x162830 | 1-bit to 2-bit address driver | [implemented](ttl_74xx/spec/chips/ttl_74x162830.md) |
| Unknown | 74x162831 | 1-bit to 4-bit address register/driver | [pending](ttl_74xx/spec/chips/ttl_74x162831.md) |
| Unknown | 74x162832 | 1-bit to 4-bit address register/driver | [pending](ttl_74xx/spec/chips/ttl_74x162832.md) |
| Unknown | 74x162834 | 3.3-V CMOS 18-bit universal bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x162834.md) |
| Unknown | 74x162835 | 18-bit universal bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x162835.md) |
| Unknown | 74x162836 | 20-bit universal bus driver | [implemented](ttl_74xx/spec/chips/ttl_74x162836.md) |
| Unknown | 74x162841 | 20-bit bus interface D-type latch | [implemented](ttl_74xx/spec/chips/ttl_74x162841.md) |
| Unknown | 74x164245 | 16-bit dual supply bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x164245.md) |
| Unknown | 74x18245 | scan test devices with 18-bit bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x18245.md) |
| Unknown | 74x18502 | scan test devices with 18-bit universal bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x18502.md) |
| Unknown | 74x18504 | scan test devices with 20-bit universal bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x18504.md) |
| Unknown | 74x18512 | scan test devices with 18-bit universal bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x18512.md) |
| Unknown | 74x18640 | scan test devices with 18-bit inverting bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x18640.md) |
| Unknown | 74x18646 | scan test devices with 18-bit transceivers and registers | [pending](ttl_74xx/spec/chips/ttl_74x18646.md) |
| Unknown | 74x18652 | scan test devices with 18-bit transceivers and registers | [pending](ttl_74xx/spec/chips/ttl_74x18652.md) |
| Unknown | 74x182502 | scan test devices with 18-bit universal bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x182502.md) |
| Unknown | 74x182504 | scan test devices with 20-bit universal bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x182504.md) |
| Unknown | 74x182512 | scan test devices with 18-bit universal bus transceivers | [pending](ttl_74xx/spec/chips/ttl_74x182512.md) |
| Unknown | 74x182646 | scan test devices with 18-bit transceivers and registers | [pending](ttl_74xx/spec/chips/ttl_74x182646.md) |
| Unknown | 74x182652 | scan test devices with 18-bit transceivers and registers | [pending](ttl_74xx/spec/chips/ttl_74x182652.md) |
| Unknown | 74x20245 | 20-bit dual supply bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x20245.md) |
| Unknown | 74x22033 | 8-bit LVTTL-to-GTLP adjustable edge rate registered transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x22033.md) |
| Unknown | 74x22501 | 8-bit universal bus transceiver and two 1-bit bus transceivers | [implemented](ttl_74xx/spec/chips/ttl_74x22501.md) |
| Unknown | 74x25244 | 25-Ω octal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x25244.md) |
| Unknown | 74x25245 | 25-Ω octal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x25245.md) |
| Unknown | 74x25642 | 25-Ω octal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x25642.md) |
| Unknown | 74x29821 | 10-bit bus interface flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x29821.md) |
| Unknown | 74x29825 | 8-bit bus interface flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x29825.md) |
| Unknown | 74x29827 | 10-bit bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x29827.md) |
| Unknown | 74x29828 | 10-bit bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x29828.md) |
| Unknown | 74x29841 | 10-bit bus interface D-type latches | [implemented](ttl_74xx/spec/chips/ttl_74x29841.md) |
| Unknown | 74x29843 | 9-bit bus interface D-type latches | [implemented](ttl_74xx/spec/chips/ttl_74x29843.md) |
| Unknown | 74x29854 | 8-bit to 9-bit parity bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x29854.md) |
| Unknown | 74x29863 | 9-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x29863.md) |
| Unknown | 74x29864 | 9-bit bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x29864.md) |
| Unknown | 74x32240 | 32-bit bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x32240.md) |
| Unknown | 74x32244 | 32-bit bus buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x32244.md) |
| Unknown | 74x32245 | 36-bit bus tranceiver | [implemented](ttl_74xx/spec/chips/ttl_74x32245.md) |
| Unknown | 74x32316 | 16-bit tri-port universal bus exchangers | [pending](ttl_74xx/spec/chips/ttl_74x32316.md) |
| Unknown | 74x32318 | 18-bit tri-port universal bus exchangers | [pending](ttl_74xx/spec/chips/ttl_74x32318.md) |
| Unknown | 74x32373 | 32-bit D-type latches | [implemented](ttl_74xx/spec/chips/ttl_74x32373.md) |
| Unknown | 74x32374 | 32-bit D-type flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x32374.md) |
| Unknown | 74x32501 | 36-bit universal bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x32501.md) |
| Unknown | 74x32543 | 36-bit registered bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x32543.md) |
| Unknown | 74x32973 | 16-bit bus transceiver and transparent D-type latch | [implemented](ttl_74xx/spec/chips/ttl_74x32973.md) |
| Unknown | 74x322244 | 32-bit buffer/driver | [implemented](ttl_74xx/spec/chips/ttl_74x322244.md) |
| Unknown | 74x322374 | 32-bit D-type flip-flops | [implemented](ttl_74xx/spec/chips/ttl_74x322374.md) |
| Unknown | 74x324245 | 32-bit dual supply bus transceiver | [implemented](ttl_74xx/spec/chips/ttl_74x324245.md) |
The 6507 year is historically reported as 1975; the exact manufacturer launch
notice remains unverified. Technical package behavior uses the MOS family
datasheet and photographed die ties. See the [6507 overview](mos_6507/README.md)
for sources and the [measured package report](mos_6507/report/final_report.md).

The 6510 entry uses a by-1982 bound from the manufacturer's November 1982
preliminary datasheet. See the [6510 history and source ledger](mos_6510/README.md)
and [measured report](mos_6510/report/final_report.md), including the
independent emulators' reset disagreement and sampled charge limitations.

The 6526 is documented by the November 1981 preliminary manufacturer sheet;
its exact launch remains unconfirmed. The [CIA overview](mos_6526/README.md)
separates the verified timer foundation from the remaining device work.

The Ricoh RP2A03 and RP2C02 entries record **1983**, the year the Family
Computer that introduced them launched in Japan
([history](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System#History)).
No month-level chip date is asserted. Behaviour is sourced from the NESdev
wiki, which is compiled from the Visual 2A03/2C02 die simulations and
hardware tests; see the [2A03 overview](ricoh_2a03/README.md),
[2C02 overview](ricoh_2c02/README.md) and their measured reports.
