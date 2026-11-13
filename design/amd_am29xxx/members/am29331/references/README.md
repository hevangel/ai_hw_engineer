# External oracle and microcode provenance

[AMD 1988 Am29C300/29300 Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf),
SHA256 `c125ee9170f7569168cd342506154a3729cd00999c853e293b681731824e0d99`,
Am29331 datasheet pages 3-1–3-33 (PDF 128–163), supplies
`instructions.csv`: Tables 1 and 2 (PDF 137, 141–149), the test-condition
table and architecture text (PDF 134–136), and the interrupt/trap/hold
prose with Figures 4–7 (PDF 136–140). The final production datasheet
governs; the 1985 advanced-information handbook was cross-checked page by
page. The CSV was transcribed and visually checked from page images before
RTL. The generator and the formal table interpret the CSV, never RTL cases.

[AMD 1985 Am29300 Family Handbook](https://bitsavers.trailing-edge.com/components/amd/bitslice/1985_AM29300_Family_Handbook.pdf),
SHA256 `80be29809b2f04448672082419f40544c968241e7cd44ed1e0335f9c4ab5f0b6`,
PDF 100–112, supplies the 1985 polarity cross-check (RST active-low
confirmation, ERROR polarity delta, A-FULL wording) and Figure 2 control
constructs that the 1988 book reproduces as Figure 3.

The Figure 3 microcode constructs and the Figures 4–7 interrupt and trap
cycles are original AMD execution examples; the driver realizes them with
implied continue words made explicit. They are not a recovered application
ROM, and exact executed/next addresses are checked with unmapped execution
fatal.

Third-party sources were not needed as oracles: the manufacturer tables
are complete for every opcode and both condition polarities. No
reconstructed behavioral model from another project is used as golden.
