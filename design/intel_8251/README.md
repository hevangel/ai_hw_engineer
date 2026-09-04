# Intel 8251 / 8251A Universal Synchronous/Asynchronous Receiver Transmitter

The Intel 8251, and its refined successor the 8251A, is a programmable serial
communication peripheral. The CPU writes parallel characters to it and the device
serializes them onto a transmit line; it deserializes a receive line back into
parallel characters the CPU reads. Character length, parity, stop-bit count,
baud-rate clock division, and synchronous versus asynchronous framing are all
programmed at run time through a short instruction sequence written to a single
control port.

## Historical context

The earliest dated Intel documentation located for the 8251 is the September
1975 *Intel 8080 Microcomputer Systems User's Manual*, which describes it as the
8251 Programmable Communication Interface. The index therefore records
**1975\*** as a documentation date rather than as a claim about a commercial
launch date; the part may have become available earlier or later, and that
uncertainty is retained rather than guessed. Dated Intel references for the later
variants are narrower: an industrial-grade `ID8251` appears in the March/April
1979 *Intel Preview*, and the 8251A in the May/June 1980 issue. Neither is
necessarily the introduction date of that variant.

The device mattered because it made serial communication a programmable
peripheral rather than a board of discrete logic. A single part covered
teletype-style asynchronous links and synchronous protocols including IBM
bi-sync, handled parity generation and checking, reported parity, overrun, and
framing errors, and exposed modem handshake lines to software. It became the
standard serial interface across MCS-80 and MCS-85 systems and their
descendants, shipping in Intel's own SDK-86 design kit, in the DEC LA120
printing terminal, and in RS-232 interface kits for amateur radio equipment. It
is frequently confused with the unrelated National Semiconductor 8250 UART that
the IBM PC used instead.

## Repository implementation

This design implements the complete digital programming model:

- the four-step programming sequence: mode instruction, one or two sync
  characters in synchronous mode, then any number of command instructions;
- asynchronous framing with a start bit, 5 to 8 data bits, optional odd or even
  parity, and 1, 1.5, or 2 stop bits;
- baud-rate clock division of 1x, 16x, or 64x, with mid-bit receive sampling and
  false-start-bit rejection at 16x and 64x;
- synchronous framing with contiguous characters, single or double sync
  character, internal sync-pattern detection or external sync input, hunt-mode
  restart, and automatic sync-character fill on transmitter underrun;
- double-buffered transmit and receive datapaths with the `TxRDY`, `TxEMPTY`, and
  `RxRDY` handshake outputs and the readable status byte;
- parity, overrun, and framing error flags with the software error-reset command;
- break transmission, and break detection over two consecutive all-zero frames;
- modem control: `DTR` and `RTS` driven from the command word, `DSR` readable in
  status, and `CTS` gating character launch;
- the software internal reset that returns the device to the mode-instruction
  state.

The original NMOS part derives its internal timing from a `CLK` pin while
sampling serial data on the free-running `TxC` and `RxC` baud clocks. This
repository uses a single-clock synthesizable core: the CPU bus, the serial input,
and the modem inputs are all sampled on `clk`, while read data, the handshake
outputs, and the shared sync/break pin are combinational. `TxC` and `RxC` are
modeled as `txc_tick` and `rxc_tick`, single-cycle enable pulses that the
environment asserts once per baud-clock edge, and a synchronous active-low
`rst_n` establishes a defined un-programmed state. Separate input, output, and
output-enable signals represent the shared CPU data bus and the shared
`SYNDET`/`BD` pin. This preserves functional ordering without claiming pin-level
timing, metastability behavior, NMOS/TTL electrical behavior, or package
compatibility.

## Documentation

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Simulation test plan](plans/testplan.md)
- [Formal verification plan](plans/formal_plan.md)
- [Coverage report](report/coverage_report.md)
- [Final report](report/final_report.md)

## Sources

- [Intel 8251A datasheet reproduction, alldatasheet](https://www.alldatasheet.com/datasheet-pdf/pdf/66096/INTEL/8251A.html)
- [98-153B Intel 8080 Microcomputer Systems User's Manual, September 1975, bitsavers archive](https://archive.org/details/bitsavers_intelMCS80ocomputerSystemsUsersManual197509_43049640)
- [Intel 8251 historical summary and dated Intel Preview references](https://en.wikipedia.org/wiki/Intel_8251)
- [NJIT EE395 8251A programming notes, mode/command/status bit assignments](https://web.njit.edu/~gilhc/EE395/8251int.htm)

Source content is summarized and rephrased for licensing compliance; no source
text is reproduced verbatim beyond device names, signal names, and field
mnemonics.
