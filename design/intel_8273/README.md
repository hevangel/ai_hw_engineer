# Intel 8273 HDLC/SDLC protocol controller

The 8273 moved serial packet framing, bit stuffing and error checking into a
programmable peripheral, freeing an 8080/8085-era CPU to handle complete frames.
Its separate transmit/receive engines, address/control buffers and DMA requests
made full-duplex synchronous links practical with modest host overhead.

First introduced: **1977***. Intel's advertisement in the November 22, 1977
issue of *Electronic Design* lists the 8273 and identifies fourth-quarter 1977
availability ([contemporary Intel advertisement](https://device.report/m/8bc5b6376694b97e23c2f7405d8292f666953225fb3eb6506aa146bfc391ae7c)).
This establishes the announced availability year, not an exact first shipment
date. The later technical revision used here is Intel 210479-004, October 1992,
reproduced after a Rochester cover in the [local datasheet](references/intel_8273.pdf)
([download source](https://datasheet.octopart.com/P8273-Intel-datasheet-38976656.pdf)).
The shared [1981 Peripheral Design Handbook](../../references/1981_Intel_Peripheral_Design_Handbook.pdf)
is also saved for subsequent peripheral designs.

This implementation transmits and receives actual serial HDLC/SDLC frames:
flags, cross-byte stuffing, reflected FCS, NRZ/NRZI, buffered/unbuffered A/C,
selective receive, DMA/non-DMA service, persistent result interrupts, modem
controls, preframe sync, transparent transmission, abort and SDLC loop relay.
A separate DPLL helper recovers receive sample strobes from 32x NRZI sampling.

The core uses one common clock with serial edge strobes and separated bus input,
output and enable signals. It is a functional recreation: original electrical
timing and internal microcode timing are not reproduced. Early Tx notifications
are supported, but queued single-flag chaining and automatic supervisory frame
repetition are outside this version. Partial-byte receive data is not delivered.
DPLL interval retention is an explicitly tested assumption, not a claim of
identical original-silicon jitter behavior. See the [specification](spec/spec.md).

The independent wire oracle uses Python's C CRC implementation with the framing
rules and residue from [RFC 1662](https://www.rfc-editor.org/rfc/rfc1662.html).
The integration demo connects two 8273s over a full-duplex NRZI cable and uses
the actual [8237A core](../intel_8237/) on all four DMA channels to move memory.
The maximum-length test compares every bit of a 65,535-byte information frame
against separately generated vectors and verifies its internal serial loopback.

Run the complete flow inside the repository's Linux toolchain container:

```sh
sh design/intel_8273/scripts/run_all.sh
```

See the [implementation plan](plans/implementation_plan.md),
[test plan](plans/testplan.md), [formal plan](plans/formal_plan.md),
[sources and oracle provenance](references/README.md),
[serial/DMA integration guide](docs/integration.md),
[coverage report](report/coverage_report.md) and [final report](report/final_report.md).
