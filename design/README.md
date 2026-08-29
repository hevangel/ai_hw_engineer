# Chip Designs

This directory contains the historical chip designs recreated and verified by the project. Each entry records the year in which the chip was first introduced and links to the design folder.

## Chip index

| Chip | Description | First introduced | Design |
|---|---|---:|---|
| Intel 4004 | 4-bit microprocessor, the first commercial single-chip CPU (MCS-4) | 1971 | [intel_4004](intel_4004/) |
| 74181 / SN74LS181 | 4-bit TTL arithmetic logic unit and function generator | 1970 | [alu_74181](alu_74181/) |
| Intel 4001 | 2048-bit mask-programmable ROM + 4-bit I/O port chip (MCS-4) | 1971 | [intel_4001](intel_4001/) |
| Intel 4003 | 10-bit serial-in/parallel-out shift-register I/O expander (MCS-4) | 1971 | [intel_4003](intel_4003/) |
| Intel 8255 / 8255A | 24-line programmable peripheral interface | 1975* | [intel_8255](intel_8255/) |
| Intel 8253 / 8254 | Three-channel programmable interval timers | 1975* / 1982* | [intel_8253_8254](intel_8253_8254/) |
| Intel 8259 / 8259A | Eight-input programmable interrupt controller | 1976 | [intel_8259](intel_8259/) |
| Intel 4002 | 320-bit RAM (256×4 main + 16×4 status) + 4-bit output port (MCS-4) | 1971 | [intel_4002](intel_4002/) |

The Intel 4004 entry records **1971**: Intel announced the 4004 on November 15, 1971 in Electronic News as the MCS-4 central processor developed for the Busicom 141-PF calculator, making it the first commercially available microprocessor, per the [Intel 4004 historical summary](https://en.wikipedia.org/wiki/Intel_4004) and the [Intel 4004 anniversary project](https://www.4004.com/). Technical behavior is sourced from the [scanned MCS-4 user manual](http://codeabbey.github.io/heavy-data-1/msc4-manual.pdf), instruction-set transcriptions at the [e4004 project](http://e4004.szyc.org/iset.html) and [pastraiser](https://pastraiser.com/cpu/i4004/i4004_opcodes.html), and cross-checked against the [MAME MCS-40 core](https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp), summarized in the design's [specification](intel_4004/spec/spec.md).

The 74181 entry uses **1970** as the introduction year. Historical references differ on the exact month, so the index intentionally records the year rather than a month-level date. The year is supported by the [74181 historical summary](https://en.wikipedia.org/wiki/74181) and [Ken Shirriff's historical analysis](https://www.righto.com/2017/03/inside-vintage-74181-alu-chip.html). Technical device information is available from [Texas Instruments' SN54S181 product page](https://www.ti.com/product/SN54S181) and the design's [specification](alu_74181/spec/spec.md).

The Intel 8255 entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. Historical summaries place development in the first half of the 1970s, a September 1975 Intel systems manual documents the device, and the [Computer History Museum catalogs an Intel 8255A applications note from 1976](https://www.computerhistory.org/collections/catalog/102671978). The precise introduction date may be earlier; this uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel datasheet reproduction](https://www.cambridge.org/core/books/ibmpc-in-the-laboratory/8255-programmable-peripheral-interface-data-sheets/1B5F5ABF95580D00D463BA07BF9A892A) and the design's [specification](intel_8255/spec/spec.md).

The Intel 8253/8254 entry uses **1975*** and **1982*** as the earliest located dated Intel documentation for each device, not as exact commercial launch claims. The 8253 appears in Intel's [September 1975 8080 systems manual](https://archive.org/details/intel8080microco00inte), while Intel's [1982 Systems Data Catalog](https://archive.org/stream/bitsavers_inteldataBCatalog_75793335/1982_Systems_Data_Catalog_djvu.txt) contains preliminary 8254 material. Availability may have preceded those documents, so the uncertainty is retained. Technical behavior is documented in the design's [specification](intel_8253_8254/spec/spec.md).

The Intel 8259/8259A entry records **1976**, the year the 8259 was introduced as part of Intel's MCS-85 family, per the [8259 historical summary](https://en.wikipedia.org/wiki/Intel_8259). The exact commercial launch date within 1976 was not established, so the index records the year rather than a month-level date. The later 8259A added 8086/8088 mode and became a fixture of the IBM PC/AT interrupt architecture. Technical behavior is sourced from the [Intel 8259A datasheet reproduction](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf) and the [Intel "Programming the 8259A" application note](http://www.idc-online.com/technical_references/pdfs/electronic_engineering/Programming_THE_8259A.pdf), summarized in the design's [specification](intel_8259/spec/spec.md).

The Intel 4001 entry records **1971**, the year the MCS-4 family (4004 CPU, 4001 ROM + I/O, 4002 RAM, 4003 shift register) reached the market. The family was developed for the Busicom 141-PF calculator and announced through Intel's advertisement in the November 15, 1971 issue of *Electronic News*, the date the industry treats as the first commercial microprocessor announcement ([EDN](https://www.edn.com/intel-4004-is-announced-november-15-1971/), [Computer History Museum](https://www.computerhistory.org/tdih/november/15/)); the November 1971 [MCS-4 data sheet](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf) is the earliest located Intel document describing the 4001 as the set's mask-programmable program storage. The November 15 date is specifically the advertisement's publication date and some accounts frame earlier mentions differently; the year itself is not in dispute. Technical behavior is sourced from the [MCS-4 Users Manual scan](https://archive.org/details/bitsavers_intelMCS4M_18342130) and the design's [specification](intel_4001/spec/spec.md).

The Intel 4003 entry records **1971**: it is the I/O expander of the MCS-4
chip set (4004 CPU, 4001 ROM, 4002 RAM, 4003 shift register) announced on
November 15, 1971 in Intel's *Electronic News* advertisement, and the
November 1971 MCS-4 data catalog already contains the 4003 data sheet, so
the part shipped with the family from launch. Secondary retellings differ
on how prominently the support chips figured in the original ad, and the
exact volume-shipping date is not established; the year is retained rather
than a month-level claim. Despite informal summaries calling it a 16-bit
part, the [MCS-4 Users Manual (February 1973)](https://archive.org/stream/bitsavers_intelMCS4M_18342130/MCS-4_UsersManual_Feb73_djvu.txt),
the [November 1971 data sheet scan](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf)
and [IEEE's "The History of the 4004"](https://www.computer.org/csdl/magazine/mi/1996/06/m6010/13rRUytWFdY)
uniformly describe a 10-bit serial-in/parallel-out, serial-out static shift
register; technical behavior is summarized in the design's [specification](intel_4003/spec/spec.md)
and [historical overview](intel_4003/README.md).

Source material is summarized and rephrased for licensing compliance.

## Design documentation

Each chip folder contains its own historical overview, specification, implementation plans, RTL, verification environment, formal properties, scripts, and reports. Start with the chip folder's `README.md` for historical context and links to its Markdown documentation.
