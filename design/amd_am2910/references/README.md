# External oracle and firmware provenance

[AMD 1978 Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
SHA256 823513eaf25d19e6ae992809afcd3116bf8cb27b4b0657256842d61c6a56c8fa,
Table I PDF99 supplies instructions.csv. It was transcribed and visually
checked before RTL. The generator interprets the data table, not RTL cases.
Figure4 PDF103 and its explanation PDF104–106 supply the historical
microprogram control flows in firmware regression. These are original AMD
execution examples with implied CONT words filled explicitly, not a claim
of a recovered complete application ROM. Exact instruction/next PCs are
checked, with unmapped execution fatal.

The third-party [Am2900ME Am2910.java](https://github.com/MaisiKoleni/Am2900ME/blob/8cf4747cdf3bb2b434359ddc248f230f9f06f81d/src/main/java/net/maisikoleni/am2900me/logic/Am2910.java)
was inspected before RTL but rejected: CJV modifies R instead of selecting D;
RFCT returns decremented counter instead of F; CRTN/LOOP/TWB use R instead
of F; RLD takes effect before address selection. Manufacturer Table I and
edge-triggered timing are authoritative. No modified copy is used as golden.
