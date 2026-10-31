# IBM AT refresh page selection — 2026-10-29

The [IBM 5170 type-1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf)
sheet 15 (PDF page 8) connects the 74LS612 map address inputs to U120/U110
gates. With refresh asserted and all DMA acknowledges inactive, MA3:MA0 is
`1111`, selecting the `8Fh` register. Sheet 13 (PDF page 7) derives `-ACK`
from HLDA and `-MASTER`; sheet 15 connects it to mapper enable. The
[Texas Instruments data book](https://manuals.plus/m/22ebd06d657b01497c50bc5de7468d9bf26b88d6006c43d4d82238c2484cab62)
states that low MM selects the addressed map register and low ME enables the
three-state outputs. The schematic grounds MM and connects MD1–MD7 to A17–A23.
MD0 goes through a separate LS125 buffer enabled by `-AEN1`, so this model
does not infer a valid XA16 merely from HLDA or refresh.

The [gate model](../tb/intel_80286_at_page_map.sv) implements these signals
with separate output-valid indications; it reuses the existing CPU-visible
page-register storage and is not a complete 12-bit LS612 model. Its directed
Verilator 5.052 `-Wall --assert` test passed in
`codex-286-at-page-map-20261029-02`, checking the drawn gate indices,
simultaneous input behavior, enable conditions, stalled writes and two
nonzero values written to and read from slot `8Fh`. Yosys `proc; opt; check
-assert; stat` found no structural problems for the gate model in
`codex-286-at-page-map-yosys-20261029-01`.

The native BIOS fixture now joins its refresh request, page storage and these
gates. In `codex-286-bios-page-map-20261029-01`, both virtual-clock/READY
scenarios again reached `F000:03A2` and matched 247,306 and 247,355 CPU
instruction states and data transactions against Unicorn using captured I/O.
Each of the 2,084 and 2,072 refresh read-drive pulses respectively checked
the row sequence, index `F`, mapper output enable, mapped page bits and
separately disabled XA16 drive against the CPU-written `8Fh` value. All 40
recorded input hashes verified after the job; the fixture holds DREQ inactive,
assumes `-MASTER` and `-AEN1` inactive, and does not implement the real DMA
grant path. The original BIOS writes `CCh`, `33h` and `00h` to `8Fh`;
the separate directed test explicitly verifies nonzero mapped output.

There is a source discrepancy: IBM's [March 1984 reference table](https://bitsavers.org/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf#page=31)
lists `88h` for DMA channel 5, while the depicted gate equations select
`8Bh` with channel 5 active and other DACKs inactive. The present test states
what the schematic gates produce; channel-5 bus operation and this discrepancy
still need independent hardware or later-revision evidence. No DMA transfer
behavior is claimed from the register fixture.

The page and row signals are not yet connected to a DRAM model, the remaining
address lines and bank selection are unresolved, and physical refresh timing
and retention remain unverified. Source screenshots in ignored
`work/at_refresh_source_20261029_01/` are `page_map_decode.png` (SHA-256
`82b153280c49a5dff0fa2e17e3af447ca899f4bd0b7843fb9e1fd1f9ab12ebe5`),
`page_map_outputs.png` (`7ec3f5e93840402587848c89642b65b6e1a0c3c2b8331e56fca0a8b5905fbf34`)
and `page_map_ack.png` (`30b2956da0b47f222f9726ee43d1bde7027a9b543b8fa9a8fe5a63c86971dcff`).
The checkpoint and the separate formal failure are recorded in
[issue comment 6516441683](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516441683).
