# AMD Am9511 arithmetic processing unit

The Am9511 adds signed 16/32-bit integer arithmetic and 32-bit floating-point
arithmetic, conversions and transcendental functions to an eight-bit host.
Its sixteen-byte rotating stack and command interface allow computation to
continue independently of the host processor. Its floating-point format has
an explicit 24-bit mantissa and an unbiased seven-bit exponent.

First introduced: **1977**. AMD's May 1981 Floating Point Processor Manual,
PDF page 26 (printed page 23), explicitly dates the original Am9511 to 1977
and the follow-on Am9512 to 1979. No exact launch month is asserted.

All 43 commands are implemented and the complete verification flow passes.
This is a synthesizable functional reconstruction with explicitly documented
rounding and sampled-interface assumptions, rather than recovered AMD microcode.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification plan](plans/testplan.md)
- [Formal proof boundary](plans/formal_plan.md)
- [Original manufacturer host programs](references/original_host.md)
- [Primary command/stack-effect table](references/commands.csv)
- [Independent-oracle assessment](references/oracle_assessment.md)
- [Progress and validation report](report/final_report.md)
- [Source-cache manifest](../../references/amd/README.md)

Primary sources:

- [AMD 1979 Designer's Guide](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf), PDF pages 235–244 and 275–296 (printed 4-33–4-42 and 5-1–5-22).
- [AMD Am9511 arithmetic processing application note](https://github.com/barberd/coco9511pak/blob/0f272e44db724ed7f0e60730499457be230e4e4f/docs/The%20Am9511%20Arithmetic%20Processing%20Unit.pdf), archived manufacturer scan; ©1978, Richard O. Parker and Joseph H. Kroeger, AM-PUB072.
- [AMD Am9511A/Am9512 processor manual](https://github.com/barberd/coco9511pak/blob/0f272e44db724ed7f0e60730499457be230e4e4f/docs/Am9511A-9512FP_Processor_Manual.pdf), later revision used only with differences identified.

The algorithm chapter starts at PDF page 275, and the detailed command
descriptions start at PDF page 284. Its table at PDF page 279 includes OCR
errors in hexadecimal codes; command codes are cross-checked against the
datasheet table at PDF page 237 and the individual command bit diagrams.

Run `sh design/amd_am9511/scripts/run_all.sh` inside the repository toolchain
container. The flow runs formal first, then all six independent simulation
suites and Yosys synthesis. `run_firmware.sh` requires the repository's existing
Am9080A design and its pinned Superzazu 8080 model. Native floating point and all
43 commands are implemented; original analog timing and microcycle counts are
outside the documented functional contract.
