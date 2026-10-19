# Original Apple II chip inventory

Scope: the original Apple II motherboard, with revision-dependent component
substitutions. This is a functional inventory, not a revision-specific bill
of materials. Sources: Apple's [1978 Reference Manual schematics](https://apple2history.org/dl/Apple_II_Redbook.pdf)
and the [revision 0 replica designer's parts list](https://www.willegal.net/appleii/assembly-v2.2.pdf).

| Function | Representative chips | Implementation role |
|---|---|---|
| Main RAM | 4116 (16K x 1); earlier 4K configurations also supported | 24 4116s provide 48 KiB; CPU and video share RAM |
| Firmware | 2 KiB ROM devices in six motherboard sockets | Integer BASIC and Monitor; original standard firmware is 8 KiB, not necessarily all sockets populated |
| Character patterns | 2513 | Text glyph ROM |
| Video, timing and address generation | 74LS161, 74LS153, 74LS257, 74166, 74LS194, 74LS283, gates and flip-flops | Counters, multiplexing, shifting and address arithmetic |
| Address decode and mode latches | 74LS138, 74LS139, 74LS259 | I/O selection and software-controlled modes |
| Bus interface | 8T28 and 8T97 | Data transceivers and bus drivers |
| Analog and timing functions | 558, 555, 741 | Paddle timing, cursor flashing and cassette input respectively |

Video is built from standard logic plus the character ROM. The onboard speaker
uses a software-controlled toggle. Optional disk and serial cards add their own
logic and are outside this motherboard list. Later IIe custom chips are not
part of this original Apple II target.

For the current FPGA-style implementation, RAM/ROM are inferred memories and
the TTL functions will be grouped into synthesizable functional modules. This
inventory does not claim a pin-by-pin reconstruction of every support chip.


## Implemented revision-0 package reconstruction

The earlier functional grouping has been superseded for the motherboard model
by individual physical packages. The source transcription contains 83 ICs:
79 wired digital packages plus H7 CPU and B3/H13/K13 analog support. Their
location/pin/net records are in [the connectivity manifest](../board/rev0_connectivity.json).
The 89-socket replica BOM also counts non-IC sockets, so it is not an IC count.

The [package library](../../../design/apple_ii_chips/README.md) contains
29 digital support models and 3 analog support models. The physical H7 CPU
uses an independent transistor reference with separately identified licenses.
[The system report](../report/final_report.md) records actual Monitor boot,
keyboard commands, physical DRAM bank tests, and remaining fidelity limits.
