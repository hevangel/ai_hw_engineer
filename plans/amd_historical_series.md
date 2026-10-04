# Historical AMD reconstruction series

Requested scope: work sequentially through the distinct parts named in the
user's early-AMD history, ending with Am8086/Am8088. This is the working scope
while the optional broader-catalog question is pending. It is not a claim to
cover every AMD product sold before 1982: the 1979 product guide includes many
additional memory, interface, logic, and analog devices. An analog part needs
a separately agreed modeling contract rather than invented digital RTL.

## Completion requirements

For each part: primary-source specification before RTL, implementation and
verification plans, synthesizable SystemVerilog, meaningful self-checking
simulation, formal proof and reachable covers where applicable, clean
Verilator lint, Yosys synthesis, historical README, index entry, and a final
report with actual results. No placeholder design counts as complete.
Processor designs additionally need historical software, an external oracle,
exact PC tests, and an assumption ledger as required by AGENTS.md.

## Queue

The order starts with the early logic/memory parts, then the processor and
bit-slice components, peripherals, and the 16-bit processors. Dates below are
research targets, not established introduction dates; each finished design
will independently source its index date. Family member ordering will be
refined from original catalogs before implementation.

| Order | Device | Function | Status |
|---:|---|---|---|
| 1 | Am9300 | Four-bit parallel-load/JK serial shift register | Verified: lint, formal BMC/prove/cover, exhaustive simulation, synthesis ([report](../design/amd_am9300/report/final_report.md)) |
| 2 | Am2501 | Binary hexadecimal synchronous up/down counter | Verified: both packages, lint, six formal tasks, exhaustive simulation/cascade, synthesis ([report](../design/amd_am2501/report/final_report.md)) |
| 3 | Am2505 | Four-by-two-bit signed multiplier/partial-product building block | Verified: lint, formal BMC/prove/cover, 32,768 slice vectors and 40,960 actual array cases, synthesis ([report](../design/amd_am2505/report/final_report.md)) |
| 4 | Am3101 | 16-word by four-bit bipolar RAM | Verified: lint, formal BMC/PDR/cover, exhaustive asynchronous memory and shared-bank simulation, synthesis ([report](../design/amd_am3101/report/final_report.md)) |
| 5 | Am9102 | 1024-bit MOS static RAM | Verified: lint, formal BMC/PDR/cover, 8,192 pin cases, March/address/standby tests and two-chip bus simulation, synthesis ([report](../design/amd_am9102/report/final_report.md)) |
| 6 | Am9080 / Am9080A | 8080-compatible CPU | Verified documented Am9080A functional core: all 244 opcodes, 16.8M external-oracle ALU checks, historical software/ISR, UVM, six formal tasks, clean lint and synthesis ([report](../design/amd_am9080/report/final_report.md)); original two-phase pin timing outside scope |
| 7 | Am2901 | Four-bit ALU/register processor slice | Verified Am2901A digital slice: all 512 words, 98,304 external-oracle cases, native phases, actual 1975 microcode/69,732 signed products, six formal tasks and synthesis; local native-latch lint exceptions documented ([report](../design/amd_am2901/report/final_report.md)) |
| 8 | Am2902 | Carry look-ahead generator | Verified: all 512 pin vectors, actual Am2901 16-bit arithmetic, five-chip 64-bit hierarchy, BMC/prove/cover, clean lint/synthesis ([report](../design/amd_am2902/report/final_report.md)) |
| 9 | Am2909 | Four-bit microprogram sequencer | Verified: 131,072 external-table transitions, original nested subroutine microcode/exact PCs, three-slice cascade, BMC/PDR/cover, clean lint and synthesis ([report](../design/amd_am2909/report/final_report.md)) |
| 10 | Am2911 | Microprogram sequencer | Verified actual shared-D/no-OR variant: 131,072 external-table transitions, original microcode/exact PCs, held/live bus checks, three-slice cascade, BMC/PDR/cover and clean lint/synthesis ([report](../design/amd_am2911/report/final_report.md)) |
| 11 | Am2910 | Microprogram controller | Verified: all sixteen instructions, 87,040 external-table transitions, 28,861 original firmware words/exact PCs, BMC/PDR/23 covers, clean lint/synthesis ([report](../design/amd_am2910/report/final_report.md)) |
| 12 | Am2903 | Enhanced processor slice | Verified: all 505 words, 415,104 external-table/native cases, original microcode on four slices+Am2910/139,464 products, BMC/PDR/cover and synthesis; localized latch/cascade lint annotations ([report](../design/amd_am2903/report/final_report.md)) |
| 13 | Am2904 | Status and shift control | Verified: all 8192 words/2,686,976 native vectors, manufacturer interrupt sequences, BMC/PDR/36 covers, clean lint and synthesis ([report](../design/amd_am2904/report/final_report.md)) |
| 14 | Am2913 | Interrupt support | Verified: all 16,384 pin cases, 4.19M actual two-chip cascade cases, nine-chip hierarchy, BMC/PDR/15 covers, clean lint/synthesis ([report](../design/amd_am2913/report/final_report.md)) |
| 15 | Am2914 | Interrupt support | Verified: all 16 operations/1,441,792 native cases, 4,608 original procedures, original 64-level cascade/4,103 cases, BMC/PDR/21 covers, clean lint/synthesis; source and timing assumptions documented ([report](../design/amd_am2914/report/final_report.md)) |
| 16 | Am2918 | Register/control support | Queued |
| 17 | Am9511 | Arithmetic processing unit | Queued |
| 18 | Am9517 | DMA controller | Queued |
| 19 | AmZ8001 | Segmented Z8000 CPU | Queued |
| 20 | AmZ8002 | Unsegmented Z8000 CPU | Queued |
| 21 | Am8086 | 16-bit x86 CPU | Queued |
| 22 | Am8088 | x86 CPU with eight-bit external data bus | Queued |

Generic labels such as “Am25xx / Am93xx” and “Am9102 etc.” are not enumerated
part numbers. Do not silently expand those labels or declare them completed.

## Sources and reproducibility

- [AMD 1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf): first logic/memory specifications.
- [AMD 1979 Designer's Guide](https://www.bitsavers.org/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf): catalog breadth and part identity cross-checks.
- [AMD 1978 Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf): bit-slice family specifications.

The source cache and its hashes are documented in
[references/amd/README.md](../references/amd/README.md). It is intentionally
separate from project-owned RTL and paraphrased documentation.
