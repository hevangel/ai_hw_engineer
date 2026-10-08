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
| 1970 | 74181 / SN74LS181 | 4-bit TTL arithmetic logic unit and function generator | [alu_74181](alu_74181/) |
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
| 1975 | MOS Technology 6502 | 8-bit microprocessor; 29-opcode subset and Apple II keyboard echo | [mos_6502](mos_6502/) |
| 1975* | Intel 8251 / 8251A | Programmable synchronous/asynchronous serial interface (USART) | [intel_8251](intel_8251/) |
| 1975* / 1982* | Intel 8253 / 8254 | Three-channel programmable interval timers | [intel_8253_8254](intel_8253_8254/) |
| 1975* | Intel 8255 / 8255A | 24-line programmable peripheral interface | [intel_8255](intel_8255/) |
| 1976* (availability evidence) | AMD Am2911 | Four-bit microprogram sequencer; shared direct/register bus, four-word return stack | [amd_am2911](amd_am2911/) |
| 1976 | Intel 8259 / 8259A | Eight-input programmable interrupt controller | [intel_8259](intel_8259/) |
| 1977 (manufacturer history) | AMD Am9511 | Signed integer/native floating arithmetic, conversions and transcendental processing unit | [amd_am9511](amd_am9511/) |
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
| 1979* (family) | Intel 8237 / 8237A | Four-channel programmable DMA controller; A-revision functional core | [intel_8237](intel_8237/) |
| 1980* / 1982* | Intel 8272 / 8272A | Four-drive floppy controller; virtual media core with FM/MFM and CRC helpers | [intel_8272](intel_8272/) |
| 1983 | Apple IIe MMU (341-0266) | Full-custom memory mapper: main/aux/bank-switched RAM selection, soft switches, ROM decode and multiplexed DRAM address | [apple_iie_mmu](apple_iie_mmu/) |
| 1983 | Apple IIe IOU (341-0267) | Full-custom video machine: display scanner and interleaved display-address fold, video-mode soft switches, keyboard strobe/auto-repeat, annunciator/speaker/cassette outputs | [apple_iie_iou](apple_iie_iou/) |

## Date provenance notes

A year marked with an asterisk (`*`) is the earliest located dated documentation or announcement, not a claim of an exact commercial launch date; availability may have preceded or followed that document, and the uncertainty is retained rather than guessed. The notes below record the sources behind each index date and are grouped by company and chip series.

### AMD — Am9300

The AMD Am9300 entry uses **1970*** for commercial availability, separating it from first working silicon in **1969**. First-person and AMD-sourced accounts differ on the exact first-shipment milestone; see the [chip history and source discussion](amd_am9300/README.md). The ongoing [historical AMD series ledger](../plans/amd_historical_series.md) records the remaining requested designs and their actual completion state.

### Apple — IIe MMU and IOU

The Apple IIe MMU and IOU entries record **1983**, the IIe's introduction month being January 1983 per the [IIe historical summary](https://en.wikipedia.org/wiki/Apple_IIe) and the [Centre for Computing History](https://www.computinghistory.org.uk/det/209/Apple-IIe); the exact introduction day is not asserted. Both parts (Apple 341-0266 / 341-0267) are Synertek-manufactured full-custom DIP-40 chips. Technical behavior follows the [Apple IIe Technical Reference Manual, 2nd ed.](https://archive.org/details/Apple_IIe_Technical_Reference_Manual) and is cross-checked against the schematic-derived CC0 [frozen-signal reimplementation](https://github.com/frozen-signal/Apple_IIe_MMU_IOU); see each design's [specification](apple_iie_mmu/spec/spec.md) ([IOU](apple_iie_iou/spec/spec.md)) for the assumption ledgers.

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

### Intel — support and peripheral devices (8237, 8251, 8253/8254, 8255, 8259, 8272, 8273, 8275, 8279)

The Intel 8237/8237A entry records **1979*** for the original 8237 family: the [May 1979 Intel 8237/8237-2 datasheet](https://web.cecs.pdx.edu/~mpj/llp/references/Intel-8237-dma.pdf) is dated by the [technical specification index](https://wiki.osdev.org/Technical_Specifications), and the [family history](https://en.wikipedia.org/wiki/Intel_8237) cites an Intel *Preview* announcement in May/June 1979. The exact introduction date of the later 8237A revision is not established; the year is not an A-revision launch claim. The design follows the [Intel 8237A datasheet](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf); implementation scope and uncertainties are documented in the [chip overview](intel_8237/README.md).

The Intel 8251/8251A entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. The device appears as the 8251 Programmable Communication Interface in Intel's [September 1975 8080 Microcomputer Systems User's Manual](https://archive.org/details/bitsavers_intelMCS80ocomputerSystemsUsersManual197509_43049640). Dated Intel references for the later variants are narrower and later: per the [8251 historical summary](https://en.wikipedia.org/wiki/Intel_8251), an industrial-grade `ID8251` appears in the March/April 1979 *Intel Preview* and the 8251A in the May/June 1980 issue, neither of which is necessarily an introduction date. Availability may therefore have preceded or followed those documents, so the uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel 8251A datasheet reproduction](https://www.alldatasheet.com/datasheet-pdf/pdf/66096/INTEL/8251A.html), cross-checked against the [NJIT EE395 8251A programming notes](https://web.njit.edu/~gilhc/EE395/8251int.htm), and summarized in the design's [specification](intel_8251/spec/spec.md).

The Intel 8253/8254 entry uses **1975*** and **1982*** as the earliest located dated Intel documentation for each device, not as exact commercial launch claims. The 8253 appears in Intel's [September 1975 8080 systems manual](https://archive.org/details/intel8080microco00inte), while Intel's [1982 Systems Data Catalog](https://archive.org/stream/bitsavers_inteldataBCatalog_75793335/1982_Systems_Data_Catalog_djvu.txt) contains preliminary 8254 material. Availability may have preceded those documents, so the uncertainty is retained. Technical behavior is documented in the design's [specification](intel_8253_8254/spec/spec.md).

The Intel 8255 entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. Historical summaries place development in the first half of the 1970s, a September 1975 Intel systems manual documents the device, and the [Computer History Museum catalogs an Intel 8255A applications note from 1976](https://www.computerhistory.org/collections/catalog/102671978). The precise introduction date may be earlier; this uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel datasheet reproduction](https://www.cambridge.org/core/books/ibmpc-in-the-laboratory/8255-programmable-peripheral-interface-data-sheets/1B5F5ABF95580D00D463BA07BF9A892A) and the design's [specification](intel_8255/spec/spec.md).

The Intel 8259/8259A entry records **1976**, the year the 8259 was introduced as part of Intel's MCS-85 family, per the [8259 historical summary](https://en.wikipedia.org/wiki/Intel_8259). The exact commercial launch date within 1976 was not established, so the index records the year rather than a month-level date. The later 8259A added 8086/8088 mode and became a fixture of the IBM PC/AT interrupt architecture. Technical behavior is sourced from the [Intel 8259A datasheet reproduction](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf) and the [Intel "Programming the 8259A" application note](http://www.idc-online.com/technical_references/pdfs/electronic_engineering/Programming_THE_8259A.pdf), summarized in the design's [specification](intel_8259/spec/spec.md).

The Intel 8272/8272A entry uses **1980*** and **1982*** as the earliest located dated Intel documentation, not exact commercial launch claims. A January 1980 Intel 8272 sheet is reproduced in the [CompuPro Disk 1 manual](https://www.bitsavers.org/pdf/compupro/Storage/171_DISK1/171F_Disk_1_Technical_Manual_1982.pdf); the [8272A preliminary sheet](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf) carries ©1982. Exact first-shipment dates were not established. See the [design overview](intel_8272/README.md) for its decoded-media scope and sources.

The Intel 8273 entry uses **1977*** for announced availability: Intel's [advertisement in Electronic Design, November 22, 1977](https://device.report/m/8bc5b6376694b97e23c2f7405d8292f666953225fb3eb6506aa146bfc391ae7c) lists the 8273 with fourth-quarter 1977 availability. An exact first-shipment date was not established. The [design overview](intel_8273/README.md) describes the sourced programming model, real serial framing and functional boundaries.

The Intel 8275 entry records **1977*** for public introduction: the contemporary [May 26, 1977 Electronics report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new controller and says sample quantities are forthcoming. This does not establish an exact first-shipment date. The design follows Intel's [8275 AFN-00224B datasheet scan](intel_8275/references/intel_8275.pdf); see the [overview](intel_8275/README.md) and [specification](intel_8275/spec/spec.md) for sources and implementation boundaries.

The 8279 entry uses **1977*** because a contemporary [May 26, 1977 *Electronics* report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new 8279 keyboard/display interface. This establishes public availability by that date but not an exact first-shipment date. The digital programming model follows the [Intel 8279/8279-5 data sheet](https://datasheets.pl/elementy_czynne/IC/8/8279.pdf) and is detailed in the [design specification](intel_8279/spec/spec.md).

### MOS Technology — 6502

The MOS Technology 6502 entry records **1975**, supported by the [IEEE historical exhibit](https://history.ieee.org/programs/ieee-global-museum/microchips-that-shook-the-world/). The exact commercial introduction date is not asserted; the index records the year rather than a month-level date. Instruction behavior is grounded in MOS Technology's [January 1976 programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf), and cycle timing must be checked against its [hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf); see the [chip overview](mos_6502/README.md).

### Texas Instruments — 74181

The 74181 entry uses **1970** as the introduction year. Historical references differ on the exact month, so the index intentionally records the year rather than a month-level date. The year is supported by the [74181 historical summary](https://en.wikipedia.org/wiki/74181) and [Ken Shirriff's historical analysis](https://www.righto.com/2017/03/inside-vintage-74181-alu-chip.html). Technical device information is available from [Texas Instruments' SN54S181 product page](https://www.ti.com/product/SN54S181) and the design's [specification](alu_74181/spec/spec.md).

Source material is summarized and rephrased for licensing compliance.

## Design documentation

Each chip folder contains its own historical overview, specification, implementation plans, RTL, verification environment, formal properties, scripts, and reports. Start with the chip folder's `README.md` for historical context and links to its Markdown documentation.
