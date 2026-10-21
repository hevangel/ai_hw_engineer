# Chip Designs

This directory contains the historical chip designs recreated and verified by the project. Each entry records the year in which the chip was first introduced and links to the design folder.

## Chip index

Sorted by first-introduced year; within a year, entries are grouped by company and then chip number. Dating conventions used in the Year column:

- `1970*` — the earliest located dated documentation or announcement, not a confirmed first-shipment date; each case is discussed in the [date provenance notes](#date-provenance-notes) below.
- `By 1978*` — located documentation proves availability no later than that year; the exact introduction year is unknown.
- Parenthesized qualifiers describe the kind of evidence behind the date (announcement, marketing material, availability evidence, manufacturer history).

| Year | Chip | Description | Design |
|---:|---|---|---|
| 1970* (commercial; silicon 1969) | AMD Am9300 | Four-bit parallel-load/JK serial shift register; asynchronous master clear | [amd_am9300](amd_am9300/) |
| 1970* | AMD Am2501 | Four-bit binary synchronous up/down counter with preset and carry look-ahead | [amd_am2501](amd_am2501/) |
| 1970 | 74181 / SN74LS181 | 4-bit TTL arithmetic logic unit and function generator | [ttl_74xx](ttl_74xx/) |
| 1971* | AMD Am2505 | Four-by-two-bit Booth multiplier/partial-product slice; both logic polarities | [amd_am2505](amd_am2505/) |
| 1971* | AMD Am3101 | 16x4 asynchronous bipolar RAM; inverted open-collector outputs | [amd_am3101](amd_am3101/) |
| 1971 | Intel 4001 | 2048-bit mask-programmable ROM + 4-bit I/O port chip (MCS-4) | [intel_4001](intel_4001/) |
| 1971 | Intel 4002 | 320-bit RAM (256×4 main + 16×4 status) + 4-bit output port (MCS-4) | [intel_4002](intel_4002/) |
| 1971 | Intel 4003 | 10-bit serial-in/parallel-out shift-register I/O expander (MCS-4) | [intel_4003](intel_4003/) |
| 1971 | Intel 4004 | 4-bit microprocessor (MCS-4); authentic Busicom manual regression | [intel_4004](intel_4004/) |
| 1972 | Intel 8008 | 8-bit microprocessor (MCS-8); SCELBAL software regression | [intel_8008](intel_8008/) |
| 1973* | Intel 3205 | One-of-eight binary decoder with active-low outputs and three chip enables; MCS-8 chip-select and state decode | [intel_3205](intel_3205/) |
| 1973* | Intel 3404 | Six-bit latch as independent 4-bit and 2-bit inverting sections with separate write enables; MCS-8 address and flag latch | [intel_3404](intel_3404/) |
| 1974* | AMD Am9102 / Am9102A / Am9102B | 1024x1 asynchronous NMOS RAM; tri-state output and retained-power standby | [amd_am9102](amd_am9102/) |
| 1974 | Intel 8080 | 8-bit microprocessor; documented instruction set on a functional transaction bus | [intel_8080](intel_8080/) |
| 1975 | AMD Am2901 | Four-bit ALU/register processor slice; documented Am2901A native clock phases and all 512 microinstructions | [amd_am2901](amd_am2901/) |
| 1975* (announcement) | AMD Am2902 | Four-group carry look-ahead generator; active-low P/G and hierarchical expansion | [amd_am2902](amd_am2902/) |
| 1975* (marketing) | AMD Am2909 | Four-bit microprogram sequencer; four-word return stack, separate register/direct buses and OR branching | [amd_am2909](amd_am2909/) |
| 1975* (Am9080A evidence) | AMD Am9080 / Am9080A | 8-bit processor; complete documented Am9080A instruction set and functional transaction bus | [amd_am9080](amd_am9080/) |
| 1975 | MOS Technology 6502 physical-bus variant | Documented NMOS ISA with pin/cycle timing for the Apple II revision-0 motherboard | [mos_6502_cycle](mos_6502_cycle/) |
| 1975 | MOS Technology 6502 | 8-bit microprocessor; full documented NMOS instruction set (151 opcodes), decimal mode, IRQ/NMI; passes Klaus Dormann's functional test | [mos_6502](mos_6502/) |
| 1975* | Intel 8251 / 8251A | Programmable synchronous/asynchronous serial interface (USART) | [intel_8251](intel_8251/) |
| 1975* / 1982* | Intel 8253 / 8254 | Three-channel programmable interval timers | [intel_8253_8254](intel_8253_8254/) |
| 1975* | Intel 8255 / 8255A | 24-line programmable peripheral interface | [intel_8255](intel_8255/) |
| 1976* (availability evidence) | AMD Am2911 | Four-bit microprogram sequencer; shared direct/register bus, four-word return stack | [amd_am2911](amd_am2911/) |
| 1976 | Intel 8259 / 8259A | Eight-input programmable interrupt controller; manufacturer-based request-withdrawal regression | [intel_8259](intel_8259/) |
| 1977 (manufacturer history) | AMD Am9511 | Signed integer/native floating arithmetic, conversions and transcendental processing unit | [amd_am9511](amd_am9511/) |
| 1977* (board use) | Apple II revision-0 support packages | 4116 RAM, ROM, 2513, TTL/bus interfaces and analog support; package years vary | [apple_ii_chips](apple_ii_chips/) |
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
| 1979* (family) | Intel 8237 / 8237A | Four-channel programmable DMA controller; original IBM PC BIOS integration | [intel_8237](intel_8237/) |
| 1980 | Intel 8087 | Architectural numeric coprocessor core; 80-bit stack, original ESC instructions and transactional memory interface | [intel_8087](intel_8087/) |
| 1980* / 1982* | Intel 8272 / 8272A | Four-drive decoded-media floppy controller; FM/MFM/CRC helpers and original IBM PC BIOS/DMA regression | [intel_8272](intel_8272/) |
| 1982 | Intel 80286 | Work in progress: 24-bit register-execution core, ALU/shifts/branches, independent instruction vectors and original IBM AT flags-test regression | [intel_80286](intel_80286/) |
| 1983 | Apple IIe MMU (341-0266) | Firmware-validated memory mapper: main/aux/bank-switched RAM selection, soft switches, ROM decode and multiplexed DRAM address | [apple_iie_mmu](apple_iie_mmu/) |
| 1983 | Apple IIe IOU (341-0267) | Firmware-validated video machine: read/write video switches, display scanner and interleaved display-address fold, video-mode soft switches, keyboard strobe/auto-repeat, annunciator/speaker/cassette outputs | [apple_iie_iou](apple_iie_iou/) |
| 1983 | Apple IIe timing PAL (PAL16R8) | Apple-programmed timing generator: φ0/φ1 CPU clocks, asymmetric Q3 strobe, PRAS'/PCAS' DRAM strobes with CAS gating, LDPS' video load and the 7 MHz dot clock | [apple_iie_pal](apple_iie_pal/) |

## Date provenance notes

A year marked with an asterisk (`*`) is the earliest located dated documentation or announcement, not a claim of an exact commercial launch date; availability may have preceded or followed that document, and the uncertainty is retained rather than guessed. The notes below record the sources behind each index date and are grouped by company and chip series.

### AMD — Am9300

The AMD Am9300 entry uses **1970*** for commercial availability, separating it from first working silicon in **1969**. First-person and AMD-sourced accounts differ on the exact first-shipment milestone; see the [chip history and source discussion](amd_am9300/README.md). The ongoing [historical AMD series ledger](../plans/amd_historical_series.md) records the remaining requested designs and their actual completion state.

### Apple — IIe MMU and IOU

The Apple IIe MMU, IOU and timing-PAL entries record **1983**, the IIe's introduction month being January 1983 per the [IIe historical summary](https://en.wikipedia.org/wiki/Apple_IIe) and the [Centre for Computing History](https://www.computinghistory.org.uk/det/209/Apple-IIe); the exact introduction day is not asserted. The MMU and IOU (Apple 341-0266 / 341-0267) are Synertek-manufactured full-custom DIP-40 chips and the timing generator is an Apple-programmed PAL16R8. Technical behavior follows the [Apple IIe Technical Reference Manual, 2nd ed.](https://archive.org/details/Apple_IIe_Technical_Reference_Manual) and is cross-checked against the schematic-derived CC0 [frozen-signal reimplementation](https://github.com/frozen-signal/Apple_IIe_MMU_IOU) (MMU/IOU only); see each design's [specification](apple_iie_mmu/spec/spec.md) ([IOU](apple_iie_iou/spec/spec.md), [PAL](apple_iie_pal/spec/spec.md)) for the assumption ledgers.

### Intel — MCS-4 family (4001, 4002, 4003, 4004)

The Intel 4001 entry records **1971**, the year the MCS-4 family (4004 CPU, 4001 ROM + I/O, 4002 RAM, 4003 shift register) reached the market. The family was developed for the Busicom 141-PF calculator and announced through Intel's advertisement in the November 15, 1971 issue of *Electronic News*, the date the industry treats as the first commercial microprocessor announcement ([EDN](https://www.edn.com/intel-4004-is-announced-november-15-1971/), [Computer History Museum](https://www.computerhistory.org/tdih/november/15/)); the November 1971 [MCS-4 data sheet](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf) is the earliest located Intel document describing the 4001 as the set's mask-programmable program storage. The November 15 date is specifically the advertisement's publication date and some accounts frame earlier mentions differently; the year itself is not in dispute. Technical behavior is sourced from the [MCS-4 Users Manual scan](https://archive.org/details/bitsavers_intelMCS4M_18342130) and the design's [specification](intel_4001/spec/spec.md).

The Intel 4002 entry records the same **1971** family year as the rest of the MCS-4 set; see the Intel 4001 note above for the family-announcement sources. No separate month-level launch claim is made.

The Intel 4003 entry records **1971**: it is the I/O expander of the MCS-4 chip set (4004 CPU, 4001 ROM, 4002 RAM, 4003 shift register) announced on November 15, 1971 in Intel's *Electronic News* advertisement, and the November 1971 MCS-4 data catalog already contains the 4003 data sheet, so the part shipped with the family from launch. Secondary retellings differ on how prominently the support chips figured in the original ad, and the exact volume-shipping date is not established; the year is retained rather than a month-level claim. Despite informal summaries calling it a 16-bit part, the [MCS-4 Users Manual (February 1973)](https://archive.org/stream/bitsavers_intelMCS4M_18342130/MCS-4_UsersManual_Feb73_djvu.txt), the [November 1971 data sheet scan](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf) and [IEEE's "The History of the 4004"](https://www.computer.org/csdl/magazine/mi/1996/06/m6010/13rRUytWFdY) uniformly describe a 10-bit serial-in/parallel-out, serial-out static shift register; technical behavior is summarized in the design's [specification](intel_4003/spec/spec.md) and [historical overview](intel_4003/README.md).

The Intel 4004 entry records **1971**: Intel announced the 4004 on November 15, 1971 in Electronic News as the MCS-4 central processor developed for the Busicom 141-PF calculator, making it the first commercially available microprocessor, per the [Intel 4004 historical summary](https://en.wikipedia.org/wiki/Intel_4004) and the [Intel 4004 anniversary project](https://www.4004.com/). Technical behavior is sourced from the [scanned MCS-4 user manual](http://codeabbey.github.io/heavy-data-1/msc4-manual.pdf), instruction-set transcriptions at the [e4004 project](http://e4004.szyc.org/iset.html) and [pastraiser](https://pastraiser.com/cpu/i4004/i4004_opcodes.html), and cross-checked against the [MAME MCS-40 core](https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp), summarized in the design's [specification](intel_4004/spec/spec.md).

### Intel — MCS-8 (3205, 3404, 8008)

The Intel 3205 entry uses **1973*** as the earliest located dated Intel documentation: the [November 1973 MCS-8 Users Manual](../references/intel_mcs8_users_manual_nov1973.pdf) prints the decoder's truth table (scan page 32) and uses 3205s throughout the SIM8-01 for 8008 state-line decoding and memory chip selects. The same manual's service note that SIM8-01 boards built prior to October 1972 must be modified shows the MCS-8 module was already in field use, so the decoder's availability may have been earlier; the uncertainty is retained rather than guessed. Function follows the combined [Intel 3205/3404 data sheet](../references/intel_3205_3404_datasheet.pdf); see the [design overview](intel_3205/README.md).

The Intel 3404 entry uses **1973*** on the same evidence: the MCS-8 manual latches the 8008's time-multiplexed address bytes and the INP flag output in 3404s across the SIM8-01 (scan page 33), and the same pre-October-1972 board-revision note implies earlier availability; the uncertainty is retained rather than guessed. The latch's transparent-while-low, store-on-rising-edge function and its independent 4-bit and 2-bit organization follow the combined [Intel 3205/3404 data sheet](../references/intel_3205_3404_datasheet.pdf); the section bit mapping and the synchronous reset artifact are recorded in the design's assumption ledger, see the [design overview](intel_3404/README.md).

The Intel 8008 entry records **1972**, with Intel dating its introduction to April 1972 in its [8008 history](https://www.intel.com/content/www/us/en/history/virtual-vault/articles/the-8008.html). Technical behavior follows the downloaded [MCS-8 Users Manual](intel_8008/references/intel_mcs8_users_manual_nov1973.md) and is checked against SCELBAL and the independent SIMH model; see the [design overview](intel_8008/README.md).

### Intel — 8080

The Intel 8080 entry records **1974**, following Intel's [manufacturer history](https://www.intel.com/content/www/us/en/newsroom/news/50-years-ago-the-influential-intel-8080.html). Announcement and release are distinguished differently in month-level retellings; no exact month is claimed here. The initial design implements documented instructions through a functional transaction bus, with Intel-specific ANA/ANI flags; native pin timing and undocumented aliases remain separate milestones. See the [design overview](intel_8080/README.md).

### Intel — 8086

The Intel 8086 entry records **1978**; Intel dates its introduction to June 8, 1978 in its [manufacturer history](https://timeline.intel.com/1978/the-beginning-of-a-legend%3A-the-8086). This design implements the complete documented instruction set, interrupts and a six-byte prefetch BIU with minimum/maximum-mode digital pins. Independent physical-chip vectors, original DEBUG.COM, formal checks and native bus tests verify the implementation; original EU cycle counts and electrical timing are outside its RTL contract. See the [chip overview](intel_8086/README.md). Its standalone software regression runs unchanged Microsoft DEBUG.COM through the execution unit and both native bus modes.

### Intel — support and peripheral devices (8237, 8251, 8253/8254, 8255, 8259, 8272, 8273, 8275, 8279)

The Intel 8237/8237A entry records **1979*** for the original 8237 family: the [May 1979 Intel 8237/8237-2 datasheet](https://web.cecs.pdx.edu/~mpj/llp/references/Intel-8237-dma.pdf) is dated by the [technical specification index](https://wiki.osdev.org/Technical_Specifications), and the [family history](https://en.wikipedia.org/wiki/Intel_8237) cites an Intel *Preview* announcement in May/June 1979. The exact introduction date of the later 8237A revision is not established; the year is not an A-revision launch claim. The design follows the [Intel 8237A datasheet](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf); implementation scope and uncertainties are documented in the [chip overview](intel_8237/README.md).

The Intel 8251/8251A entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. The device appears as the 8251 Programmable Communication Interface in Intel's [September 1975 8080 Microcomputer Systems User's Manual](https://archive.org/details/bitsavers_intelMCS80ocomputerSystemsUsersManual197509_43049640). Dated Intel references for the later variants are narrower and later: per the [8251 historical summary](https://en.wikipedia.org/wiki/Intel_8251), an industrial-grade `ID8251` appears in the March/April 1979 *Intel Preview* and the 8251A in the May/June 1980 issue, neither of which is necessarily an introduction date. Availability may therefore have preceded or followed those documents, so the uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel 8251A datasheet reproduction](https://www.alldatasheet.com/datasheet-pdf/pdf/66096/INTEL/8251A.html), cross-checked against the [NJIT EE395 8251A programming notes](https://web.njit.edu/~gilhc/EE395/8251int.htm), and summarized in the design's [specification](intel_8251/spec/spec.md).

The Intel 8253/8254 entry uses **1975*** and **1982*** as the earliest located dated Intel documentation for each device, not as exact commercial launch claims. The 8253 appears in Intel's [September 1975 8080 systems manual](https://archive.org/details/intel8080microco00inte), while Intel's [1982 Systems Data Catalog](https://archive.org/stream/bitsavers_inteldataBCatalog_75793335/1982_Systems_Data_Catalog_djvu.txt) contains preliminary 8254 material. Availability may have preceded those documents, so the uncertainty is retained. Technical behavior is documented in the design's [specification](intel_8253_8254/spec/spec.md). Original IBM Model 30 POST also validates Mode 0 count rewrites; the [failure note](../failure_notes/2026-10-15-pit-mode0-rearm.md) records the required OUT edge and added regression.

The Intel 8255 entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. Historical summaries place development in the first half of the 1970s, a September 1975 Intel systems manual documents the device, and the [Computer History Museum catalogs an Intel 8255A applications note from 1976](https://www.computerhistory.org/collections/catalog/102671978). The precise introduction date may be earlier; this uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel datasheet reproduction](https://www.cambridge.org/core/books/ibmpc-in-the-laboratory/8255-programmable-peripheral-interface-data-sheets/1B5F5ABF95580D00D463BA07BF9A892A) and the design's [specification](intel_8255/spec/spec.md).

The Intel 8259/8259A entry records **1976**, the year the 8259 was introduced as part of Intel's MCS-85 family, per the [8259 historical summary](https://en.wikipedia.org/wiki/Intel_8259). The exact commercial launch date within 1976 was not established, so the index records the year rather than a month-level date. The later 8259A added 8086/8088 mode and became a fixture of the IBM PC/AT interrupt architecture. Technical behavior is sourced from the [Intel 8259A datasheet reproduction](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf) and the [Intel "Programming the 8259A" application note](http://www.idc-online.com/technical_references/pdfs/electronic_engineering/Programming_THE_8259A.pdf), summarized in the design's [specification](intel_8259/spec/spec.md).

The Intel 8272/8272A entry uses **1980*** and **1982*** as the earliest located dated Intel documentation, not exact commercial launch claims. A January 1980 Intel 8272 sheet is reproduced in the [CompuPro Disk 1 manual](https://www.bitsavers.org/pdf/compupro/Storage/171_DISK1/171F_Disk_1_Technical_Manual_1982.pdf); the [8272A preliminary sheet](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf) carries ©1982. Exact first-shipment dates were not established. See the [design overview](intel_8272/README.md) for its decoded-media scope and sources.

The Intel 8273 entry uses **1977*** for announced availability: Intel's [advertisement in Electronic Design, November 22, 1977](https://device.report/m/8bc5b6376694b97e23c2f7405d8292f666953225fb3eb6506aa146bfc391ae7c) lists the 8273 with fourth-quarter 1977 availability. An exact first-shipment date was not established. The [design overview](intel_8273/README.md) describes the sourced programming model, real serial framing and functional boundaries.

The Intel 8275 entry records **1977*** for public introduction: the contemporary [May 26, 1977 Electronics report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new controller and says sample quantities are forthcoming. This does not establish an exact first-shipment date. The design follows Intel's [8275 AFN-00224B datasheet scan](intel_8275/references/intel_8275.pdf); see the [overview](intel_8275/README.md) and [specification](intel_8275/spec/spec.md) for sources and implementation boundaries.

The 8279 entry uses **1977*** because a contemporary [May 26, 1977 *Electronics* report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new 8279 keyboard/display interface. This establishes public availability by that date but not an exact first-shipment date. The digital programming model follows the [Intel 8279/8279-5 data sheet](https://datasheets.pl/elementy_czynne/IC/8/8279.pdf) and is detailed in the [design specification](intel_8279/spec/spec.md).

### MOS Technology — 6502

The MOS Technology 6502 entry records **1975**, supported by the [IEEE historical exhibit](https://history.ieee.org/programs/ieee-global-museum/microchips-that-shook-the-world/). The exact commercial introduction date is not asserted; the index records the year rather than a month-level date. Instruction behavior is grounded in MOS Technology's [January 1976 programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf), and cycle timing must be checked against its [hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf); see the [chip overview](mos_6502/README.md).

### Texas Instruments — 74181

The 74181 entry uses **1970** as the introduction year. Historical references differ on the exact month, so the index intentionally records the year rather than a month-level date. The year is supported by the [74181 historical summary](https://en.wikipedia.org/wiki/74181) and [Ken Shirriff's historical analysis](https://www.righto.com/2017/03/inside-vintage-74181-alu-chip.html). Technical device information is available from [Texas Instruments' SN54S181 product page](https://www.ti.com/product/SN54S181) and the design's [specification](ttl_74xx/spec/spec.md).

Source material is summarized and rephrased for licensing compliance.

## Design documentation

Each chip folder contains its own historical overview, specification, implementation plans, RTL, verification environment, formal properties, scripts, and reports. Start with the chip folder's `README.md` for historical context and links to its Markdown documentation.

## System integration updates

The [1983 IBM XT platform](../system/ibm_pc_xt_5160/README.md) uses the Intel
8086 core's additional ESC/WAIT observation outputs and the Intel 8087's
execution-gated numeric datapaths. The chip introduction years and respective
architectural verification boundaries above remain unchanged.

### Apple — revision-0 support packages

The grouped support-package entry records **1977 board use**, established by
the [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf),
rather than asserting a common first-introduced year for the individual TTL,
RAM, ROM and analog parts. Individual variant dates remain unestablished;
see the [package overview](apple_ii_chips/README.md).

Apple IIe board integration now exercises the unchanged original ROM, BASIC and
80-column firmware. Primary-manual corrections to Cxxx ROM selection and
read-side video switches are documented in the [platform](../system/apple_iie/)
and [post-mortem](../failure_notes/2026-10-19-apple-iie-rom-switches.md).

## Classic 7400–74299 digital functions

All functions are grouped in [ttl_74xx](ttl_74xx/README.md). Unknown* records an unestablished first-introduced year; manufacturer sources and normalized interface contracts are linked per part. The seven analog/timing exclusions are listed in the library overview.

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
