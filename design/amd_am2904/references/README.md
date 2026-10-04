# Independent manufacturer oracle

`status.csv` is a 64-row transcription of AMD 1979 family book Tables1–4/6
(PDF94–97). `shift.csv` transcribes Table7 (PDF98). These artifacts were
authored before RTL from visually inspected scans. Expressions use one-bit
Boolean operators; U/M/I/Y prefixes denote pre-edge micro status, machine
status, input status and external Y, respectively. Z/C/N/V suffixes identify
the four bits. S0/SN/Q0/QN are external shift pin values. `-` means release or
no shift carry load. Codes in CSV are hexadecimal, despite octal status
instruction numbers in the original printed tables.

[Primary source](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf),
printed2-86–2-90. See [specification](../spec/spec.md) for carry hold exceptions
and output representations. [Generator](../scripts/generate_oracle.py) reads
only these CSV files; its outputs are committed and checked for staleness.
The C++ interpreter applies independently expressed bit masks and pin packing;
formal next-state logic uses the same external table transcription.

This is a manufacturer-derived oracle, not an independent transcription by a
second researcher. The original interrupt restoration/swap examples and
explicit borrow/sticky overflow checks supply additional semantic validation.
The [Am2900ME Am2904 implementation](https://github.com/MaisiKoleni/Am2900ME/blob/8cf4747cdf3bb2b434359ddc248f230f9f06f81d/src/main/java/net/maisikoleni/am2900me/logic/Am2904.java)
was inspected but not used as the expected-value source: its step API mutates
status before producing outputs and does not provide the native clock/pin
sampling contract required here. No code from it is incorporated.
