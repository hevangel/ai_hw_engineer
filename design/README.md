# Chip Designs

This directory contains the historical chip designs recreated and verified by the project. Each entry records the year in which the chip was first introduced and links to the design folder.

## Chip index

| Chip | Description | First introduced | Design |
|---|---|---:|---|
| 74181 / SN74LS181 | 4-bit TTL arithmetic logic unit and function generator | 1970 | [alu_74181](alu_74181/) |
| Intel 8255 / 8255A | 24-line programmable peripheral interface | 1975* | [intel_8255](intel_8255/) |
| Intel 8253 / 8254 | Three-channel programmable interval timers | 1975* / 1982* | [intel_8253_8254](intel_8253_8254/) |
| Intel 8259 / 8259A | Eight-input programmable interrupt controller | 1976 | [intel_8259](intel_8259/) |
| Intel 4002 | 320-bit RAM (256×4 main + 16×4 status) + 4-bit output port (MCS-4) | 1971 | [intel_4002](intel_4002/) |

The 74181 entry uses **1970** as the introduction year. Historical references differ on the exact month, so the index intentionally records the year rather than a month-level date. The year is supported by the [74181 historical summary](https://en.wikipedia.org/wiki/74181) and [Ken Shirriff's historical analysis](https://www.righto.com/2017/03/inside-vintage-74181-alu-chip.html). Technical device information is available from [Texas Instruments' SN54S181 product page](https://www.ti.com/product/SN54S181) and the design's [specification](alu_74181/spec/spec.md).

The Intel 8255 entry uses **1975*** as the earliest located dated Intel documentation, not as a claim of an exact commercial launch date. Historical summaries place development in the first half of the 1970s, a September 1975 Intel systems manual documents the device, and the [Computer History Museum catalogs an Intel 8255A applications note from 1976](https://www.computerhistory.org/collections/catalog/102671978). The precise introduction date may be earlier; this uncertainty is retained rather than guessed. Technical behavior is sourced from the [Intel datasheet reproduction](https://www.cambridge.org/core/books/ibmpc-in-the-laboratory/8255-programmable-peripheral-interface-data-sheets/1B5F5ABF95580D00D463BA07BF9A892A) and the design's [specification](intel_8255/spec/spec.md).

The Intel 8253/8254 entry uses **1975*** and **1982*** as the earliest located dated Intel documentation for each device, not as exact commercial launch claims. The 8253 appears in Intel's [September 1975 8080 systems manual](https://archive.org/details/intel8080microco00inte), while Intel's [1982 Systems Data Catalog](https://archive.org/stream/bitsavers_inteldataBCatalog_75793335/1982_Systems_Data_Catalog_djvu.txt) contains preliminary 8254 material. Availability may have preceded those documents, so the uncertainty is retained. Technical behavior is documented in the design's [specification](intel_8253_8254/spec/spec.md).

The Intel 8259/8259A entry records **1976**, the year the 8259 was introduced as part of Intel's MCS-85 family, per the [8259 historical summary](https://en.wikipedia.org/wiki/Intel_8259). The exact commercial launch date within 1976 was not established, so the index records the year rather than a month-level date. The later 8259A added 8086/8088 mode and became a fixture of the IBM PC/AT interrupt architecture. Technical behavior is sourced from the [Intel 8259A datasheet reproduction](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf) and the [Intel "Programming the 8259A" application note](http://www.idc-online.com/technical_references/pdfs/electronic_engineering/Programming_THE_8259A.pdf), summarized in the design's [specification](intel_8259/spec/spec.md).

Source material is summarized and rephrased for licensing compliance.

## Design documentation

Each chip folder contains its own historical overview, specification, implementation plans, RTL, verification environment, formal properties, scripts, and reports. Start with the chip folder's `README.md` for historical context and links to its Markdown documentation.
