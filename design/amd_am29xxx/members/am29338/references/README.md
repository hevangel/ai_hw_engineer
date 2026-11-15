# External oracle provenance

[AMD 1988 Am29C300/29300 Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf),
SHA256 `c125ee9170f7569168cd342506154a3729cd00999c853e293b681731824e0d99`,
Am29338 datasheet PDF 242–263 (advance information): Tables 1–4, the
Figures 6/7 queuing/dequeuing examples and the Figure 5 retransmit
example were transcribed from page images before RTL. The functional
model in `scripts/generate_oracle.py` implements the byte-stream
semantics (ring, BSW reorder, LSB-first disassembly, pointer windows,
parity travel) from those pages.

The bring-up debug harness (pointer/mem mirror replay) is not part of
the committed suite; the committed oracle is the lockstep drive model.
