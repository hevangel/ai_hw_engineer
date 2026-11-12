# AMD Am9512 floating-point processor

The Am9512 is a stack-oriented, microprogrammed floating-point processor for
8-bit microprocessors. It provides single-precision (32-bit) and
double-precision (64-bit) add, subtract, multiply and divide, an eight-word
operand stack, a five-flag status register, and programmed-I/O or DMA-friendly
handshakes. It has no transcendental functions; that is the main functional
difference from the earlier Am9511.

First introduced: **1979**. AMD's May 1981 *Am9511A/Am9512 Floating Point
Processor Manual* dates the Am9512 to 1979, and *Electronics* described the
device in July 1979. No exact launch month is asserted.

The Am9512 is an early single-chip floating-point coprocessor. It targets the
8080/8085, Z80, 6800 and similar 8-bit hosts, and it was also sold by Intel as
the 8232. Its format is close to the draft IEEE floating-point proposal but is
not a complete later IEEE 754 implementation: it has no infinities, NaNs,
signed zeros, subnormals or gradual underflow. Zero is encoded as an all-zero
exponent field, and the mantissa is ignored for the zero test. These
differences are part of the historical contract and are tested directly.

The implementation here is a synthesizable functional reconstruction, not
recovered AMD microcode. All 16 documented commands are implemented, including
32/64-bit arithmetic, the stack operations, status, RESET, ERR, END, SVREQ and
the PAUSE handshake. The original microcode, execution-cycle counts, analog
timing and internal 17-bit stack word are outside the contract.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Command table](references/commands.csv)
- [Independent oracle and vector generator](references/oracle.md)
- [Progress and validation report](report/final_report.md)

Primary sources:

- [AMD Am9500 Peripheral Products Interface Guide (1980)](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1980_AMD_Am9500_Peripheral_Products_Interface_Guide.pdf), Am9512 chapter at printed pages 4-27 through 4-39 (PDF 74-86). This is the detailed command, format, status and algorithm source.
- [AMD Am9511A/Am9512 Floating Point Processor Manual (May 1981)](https://bitsavers.trailing-edge.com/components/amd/_dataSheets/Am9511A-9512FP_Processor_Manual.pdf), section 5.3 and the Am9512 command descriptions. The scan is image-only; its readable text agrees with the 1980 chapter.
- [Am9512 datasheet scan](https://assets.sourcengine.com/datasheets/db2b383d-7054-46fd-88c1-576bc79c864b.pdf).
- [Electronics, 5 July 1979](https://www.worldradiohistory.com/Archive-Electronics/70s/79/Electronics-1979-07-05.pdf), which described the device.

Run the complete flow in the repository toolchain container:

```sh
sh design/amd_am9512/scripts/run_all.sh
```

The flow checks generated opcode constants, runs the formal bmc/prove/cover
tasks, runs the independent-vector simulation (347 vectors by default), and
runs generic four-LUT synthesis. The simulation compares the full 16-byte
stack, status, END, ERR and SVREQ against a Python model generated from the
1980 chapter, not from the RTL.

Verification boundary: the design is a digital functional reconstruction. It
does not claim original microcycle counts, propagation delays, analog levels or
physical silicon errata. The 1980 chapter specifies the status flags but not a
special result value for exponent overflow or underflow; the reconstruction
uses a fixed-width exponent wrap for overflow and zero for underflow, and
records that choice in the assumption ledger.