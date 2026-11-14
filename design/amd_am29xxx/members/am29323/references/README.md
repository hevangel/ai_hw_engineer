# External oracle provenance

[AMD 1985 Am29300 Family Handbook](https://bitsavers.trailing-edge.com/components/amd/bitslice/1985_AM29300_Family_Handbook.pdf),
SHA256 `80be29809b2f04448672082419f40544c968241e7cd44ed1e0335f9c4ab5f0b6`,
Am29323 datasheet PDF 46–52: Tables 1–3, pin descriptions and the
X/Y/P data-format figures were transcribed from page images before RTL;
the slice model in `scripts/generate_oracle.py` implements the figure's
bit weights directly.

[AMD 1988 Am29C300/29300 Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf),
SHA256 `c125ee9170f7569168cd342506154a3729cd00999c853e293b681731824e0d99`,
Am29C323 preliminary datasheet PDF 266–289: supplies the SHIFT AND
ACCUMULATE definition (page 4-9) and the 67-bit overflow layout that the
1985 text leaves implicit.

No third-party multiplier model is used as an oracle; the functional
model in the generator is written from the datasheet text and tables and
checked against the RTL through the lockstep drive stream.
