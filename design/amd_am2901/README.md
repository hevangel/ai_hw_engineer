# AMD Am2901: four-bit processor slice

**First introduced: 1975.** The contemporary [August 1975 Microcomputer
Digest, page 1](https://bitsavers.org/magazines/Microcomputer_Digest/Microcomputer_Digest_v02n02_Aug75.pdf)
reports Am2901 availability from stock. The [Computer History Museum's
physical artifact](https://www.computerhistory.org/revolution/digital-logic/12/330/1579)
also records 1975. The exact first announcement/shipment month is not
established here. The implemented digital contract is the Am2901A sheet in
AMD's 1978 data book; revision-specific electrical timing is outside scope.

The Am2901 combines sixteen working registers, Q, a two-port register file,
an eight-function ALU and shift linkage in a four-bit slice. Designers could
combine slices into a word width suited to their machine. It made AMD a
major supplier of microprogrammed processor building blocks before x86.

All 512 microinstructions, physical signal polarities, logical-mode status,
transparent clock phases, storage and shift ports are implemented. A
separately authored emulator checks data/state behavior, manufacturer
equations check status, and the actual August 5, 1975 signed-multiply
microprogram runs on four RTL slices. The combined flow passes.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Independent oracle and original microcode](references/README.md)
- [Observed verification and tool boundaries](report/final_report.md)
- [Historical series progress](../../plans/amd_historical_series.md)

The independent oracle needs Java 21. Build the small verification overlay
once, then use it with the usual repository bind mount:

```sh
docker build -t ai-hw-am2901-verification -f design/amd_am2901/scripts/verification.Dockerfile .
# Inside that image, with the repository mounted at /workspace:
sh design/amd_am2901/scripts/run_all.sh
```

The original [1978 AMD data book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf)
provides Figures 2–4, 8 and 20–21. Separate value/enable ports represent
tri-state pins; external circuitry must satisfy setup/hold timing.
