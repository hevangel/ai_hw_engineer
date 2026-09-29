# Micral N virtual-platform specification

Primary source: [R2E Micral N User Manual, January 1974](reference/MICRAL_N_Users_Manual_Jan74.pdf) and its [searchable Markdown transcription](reference/MICRAL_N_Users_Manual_Jan74.md). The computer was introduced in 1973; the January 1974 manual documents the architecture, not a precise first-shipment date.

The virtual platform connects the repository's Intel 8008 core to 16 KiB of byte memory, input groups, output latches, and a front panel. The memory is divided into 64 pages of 256 bytes, as R2E describes in chapter III. The model supports a configurable full-memory image and host writes. It marks page 0 and pages 0x38–0x3f read-only when ROM protection is enabled, matching the recovered machine's boot and monitor locations described by the [MO5 restoration](https://hxc2001.pages-perso.free.fr/micral-n/index.html). These physical ROM locations are a restored machine's configuration, not a universal Micral N layout; R2E explicitly allows card address assignment.

The 8008 uses separate memory and I/O transactions in this virtual platform. Input opcode ports 0–7 select a group, with the current accumulator providing the input's byte index per R2E section II.2.5.2. Group 5 is connected to the panel input switch bank for the included MO5 exercise; unconnected groups return zero. Output ports 8–31 latch data for the panel. The final output port corresponds to R2E output address /17 (decimal 23) and controls the optical watchdog indicator. The exact watchdog data bit is not established by the OCR text, so the UI displays the whole output byte instead of inventing a bit interpretation.

The optional console presents AUTO, STEP, instruction/cycle step, TRAP address, SUBstitution data switches, INIT, 14 address lamps, eight data lamps, fetch/read/write/I/O lamps, and run/wait/stop state. The host backend applies STEP and TRAP at simulator cycles/instruction retirements. SUB replaces memory data during a read. INIT synchronously resets the CPU. R2E's section VI is the source for control meanings.

The default image is MO5's publicly available Micral N `8008-input-output.bin` demonstration, not the original MIC-01 monitor. Original boot and monitor ROM SHA-256 values appear on the restoration page, but their bytes were not provided there. The platform can load an authentic image when one is available. The default demo polls input group 5 for bit 7 and sends incrementing bytes to an output port.

ASSUMPTION: All bus handshakes take one simulator clock, rather than preserving original Pluribus electrical and timing details. This uses the synchronous interface defined in the 8008 design spec.

ASSUMPTION: Unconnected Micral input groups return zero; real installations used configurable coupler cards.

ASSUMPTION: The system does not emulate the graded interrupt controller or real-time clock card yet. Panel INIT resets the core, and the 8008's instruction injection input remains available for future board-level interrupt modeling. The shipped demo does not require these cards.
