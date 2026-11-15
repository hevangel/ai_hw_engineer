# External oracle provenance

[AMD 1988 Am29C300/29300 Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf),
SHA256 `c125ee9170f7569168cd342506154a3729cd00999c853e293b681731824e0d99`,
Am29337 datasheet PDF 231–241 (Issue 08548B, June 1987): Tables 1/2 and
Figure 1 were transcribed from page images before RTL. The functional
model in `scripts/generate_oracle.py` implements the signed/unsigned
comparison and the carry qualification directly from Table 1 and the
region table.

A prose/table contradiction on OOB (see spec ledger) was resolved in
favor of the visually confirmed Table 2.
