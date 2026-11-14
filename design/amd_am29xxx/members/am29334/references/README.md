# External oracle provenance

[AMD 1988 Am29C300/29300 Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf),
SHA256 `c125ee9170f7569168cd342506154a3729cd00999c853e293b681731824e0d99`,
Am29334 datasheet PDF 201–215 (Amendment 10). The functional model in
`scripts/generate_oracle.py` implements pages 3-79 pin descriptions and
the functional description including Figure 2 transparency; it was
written from the page images before RTL. No instruction table exists for
this part; the oracle is the directed/random drive model with per-byte
definedness tracking.

The [Am29434 ECL datasheet](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf)
(PDF 216–229, preliminary, Issue 08554A, September 1986) documents the
same function; the am29434 member shares this RTL per the series rules.
