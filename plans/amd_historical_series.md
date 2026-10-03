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
| 3 | Am2505 | Four-by-two-bit signed multiplier/partial-product building block | Primary specification and Booth operation table located; next implementation |
| 4 | Am3101 | 16-word by four-bit bipolar RAM | Queued |
| 5 | Am9102 | 1024-bit MOS static RAM | Queued |
| 6 | Am9080 / Am9080A | 8080-compatible CPU | Queued |
| 7 | Am2901 | Four-bit ALU/register processor slice | Queued |
| 8 | Am2902 | Carry look-ahead generator | Queued |
| 9 | Am2909 | Four-bit microprogram sequencer | Queued |
| 10 | Am2911 | Microprogram sequencer | Queued |
| 11 | Am2910 | Microprogram controller | Queued |
| 12 | Am2903 | Enhanced processor slice | Queued |
| 13 | Am2904 | Status and shift control | Queued |
| 14 | Am2913 | Interrupt support | Queued |
| 15 | Am2914 | Interrupt support | Queued |
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
