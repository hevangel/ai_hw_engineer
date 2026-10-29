# Am2911 microprogram sequencer specification

Primary contract: AMD 1978 family book, PDF 82–95; Figure 2's variant note,
Figure 6 transition table and the explicit comparison on PDF 94/95.
The Am2911 is a distinct twenty-pin device, not a renamed Am2909 interface.

It shares Am2909's four-bit µPC, enabled address register, circular four-word
stack, select codes, ZERO, OE and active-high increment carry. Its two physical
differences are mandatory: **D also supplies the enabled register**, and
**there are no address OR pins**. Independent R/OR ports must not be exposed.

`select_i`: 0=µPC, 1=held register, 2=stack top, 3=current D. `re_n_i` LOW
loads D at the rising CP edge; otherwise the held register retains its previous
value even as D changes. `zero_n_i` LOW forces internal Y=0; `oe_n_i` HIGH
releases external Y without inhibiting counter/register/stack clocks.
µPC always loads internal Y+Cn. Group carry supports cascading.

`fe_n_i` LOW enables push/pop. Push HIGH increments the two-bit pointer and
writes **pre-edge µPC** at the new top; push LOW decrements without erasing.
There is no reset or guaranteed initial state. Four real pushes initialize
all physical stack words regardless of initial pointer; unwritten values are
unspecified. Edge-based digital transitions follow Figure 6; electrical SRAM
write timing and propagation delays are outside this reconstruction.

Use the separately documented Am2909 state engine with R tied to D and OR
tied to zero, exactly as the manufacturer's block-diagram note specifies.
Verification uses the external Figure 6 top-first list oracle with register
loads explicitly changed to D. Figures 7/8 control sequences also apply and
must execute on three actual Am2911 slices with exact executed/next PCs.
No undocumented semantic assumptions or fabricated reset are introduced.

Sources: [AMD family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
[May 1976 contemporary availability report, page 10](https://deramp.com/downloads/mfe_archive/070-Books%20Newsletters%20and%20Magazines/Microcomputer%20Digest/Microcomputer_Digest_v02n11_May76.pdf).
