# Intel 8255 Programmable Peripheral Interface

The Intel 8255, later refined as the 8255A, is a programmable parallel-I/O peripheral developed for Intel's early microprocessor systems. It exposes 24 peripheral lines as three 8-bit ports and can repurpose Port C lines for strobed transfers, status, and interrupt handshaking.

## Historical context

Intel developed the 8255 for the 8080-era ecosystem in the first half of the 1970s. This index records **1975** because a September 1975 Intel 8080 systems manual is the earliest dated Intel documentation located during this implementation; the exact commercial launch date was not established, and the device may have been available earlier. Intel published a dedicated 8255A applications document in 1976. The later 8255A improved timing and drive characteristics while retaining the programming model, and CMOS 82C55-compatible parts extended the design's life.

The device mattered because it condensed three configurable parallel ports, simple bit control, strobed transfer logic, and interrupt generation into one peripheral. It became common in development systems and later products, including the original IBM PC family and MSX computers. Its programming model remains a useful compact example of multiplexing general-purpose pins with hardware protocol signals.

## Repository implementation

This design implements the complete digital programming model:

- four-address CPU register interface;
- Mode 0 simple input/output;
- Mode 1 strobed input or output on Ports A and B;
- Mode 2 bidirectional strobed operation on Port A;
- Port C handshake/status multiplexing;
- Bit Set/Reset control, including the hidden interrupt-enable flip-flops;
- input latches, output latches, buffer-full status, interrupt generation, and reset-to-input behavior.

The original NMOS part is asynchronous and has no clock pin. This repository uses a single-clock synthesizable core: active-low CPU controls and peripheral handshakes are sampled on `clk`, while read data and pin-drive values are combinational. Separate input, output, and output-enable vectors represent each bidirectional port. This preserves functional ordering without claiming pin-level timing, metastability behavior, TTL electrical behavior, or package compatibility.

## Documentation

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Simulation test plan](plans/testplan.md)
- [Formal verification plan](plans/formal_plan.md)
- [Coverage report](report/coverage_report.md)
- [Final report](report/final_report.md)

## Sources

- [Intel 8255A datasheet reproduction, Cambridge appendix](https://www.cambridge.org/core/books/ibmpc-in-the-laboratory/8255-programmable-peripheral-interface-data-sheets/1B5F5ABF95580D00D463BA07BF9A892A)
- [Archived Intel 8255A datasheet PDF](https://4donline.ihs.com/images/VipMasterIC/IC/RSEL/RSEL-S-A0000095683/RSEL-S-A0000095683-1.pdf?hkey=6D3A4C79FDBF58556ACFDE234799DDF0)
- [Intel 8255A applications note catalog record, dated 1976, Computer History Museum](https://www.computerhistory.org/collections/catalog/102671978)
- [Historical summary and cited 1975 Intel manual reference](https://en.wikipedia.org/wiki/Intel_8255)
- [Altera a8255 synthesizable-core datasheet archive](http://ebook.pldworld.com/_semiconductors/ALTERA/Digital%20Library/2000/Ver.6/DS/DS8255.PDF)

Source content is summarized and rephrased; no source text is reproduced verbatim beyond device names and signal terminology.
