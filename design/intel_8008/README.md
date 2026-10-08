# Intel 8008 microprocessor

Intel introduced the 8008 in **April 1972**, according to [Intel's historical account](https://www.intel.com/content/www/us/en/history/virtual-vault/articles/the-8008.html). It was Intel's first 8-bit microprocessor and the processor behind early systems including the Micral N and SCELBI. Its 14-bit program counter addresses 16 KiB, while an eight-entry internal address stack supports seven nested subroutines.

The repository core is a synthesizable, synchronous functional reconstruction. It implements the 8008 instruction families, flags, stack, interrupts, memory, and 32 I/O ports. It presents separate memory and I/O handshakes instead of the original time-multiplexed 18-pin electrical interface. See the [specification](spec/spec.md), [implementation plan](plans/implementation_plan.md), and [verification report](report/final_report.md).

## Sources and local copies

- [Intel MCS-8 User Manual, November 1973 (PDF)](../../../references/intel_mcs8_users_manual_nov1973.pdf), downloaded from [DeRamp's Intel archive](https://deramp.com/downloads/mfe_archive/050-Component%20Specifications/Intel/Microprocessors%20and%20Support/8008%20Family/i8008UM%20Nov%2073.pdf); [searchable Markdown transcription](references/intel_mcs8_users_manual_nov1973.md).
- [SIMH's independent 8008 model](references/simh_i8008.c), downloaded from [SIMH](https://github.com/simh/simh/blob/master/Intel-Systems/common/i8008.c). The regression model in `scripts/make_scelbal_vectors.py` follows this model's instruction semantics.
- [Authentic SCELBAL binary](references/scelbal_sc1.bin), downloaded from [Mike Willegal's SCELBI archive](https://www.willegal.net/scelbi/software/sc1.bin), following [SIMH's SCELBI instructions](https://github.com/simh/simh/blob/master/Intel-Systems/scelbi/scelbi.txt). The SIMH load address `100` is octal, or hex `0x40`.

The SCELBI Museum's separate `scelbal.hex` was inspected but contains two malformed Intel HEX records, so it is not used by the regression.

## Verification

From the repository root in the project tool image, run `sh design/intel_8008/scripts/run_all.sh`. This runs strict Verilator lint, formal proof and cover, a directed exact-PC test, a 200,000-instruction comparison against authentic SCELBAL, and Yosys synthesis. The SCELBAL run compares PC, all seven registers, all flags, stack depth, and final memory, with 475 input and 637 output transfers in the fixed regression.
