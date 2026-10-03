# Am2903 primary oracle and actual firmware

[AMD 1978 Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
SHA256 823513eaf25d19e6ae992809afcd3116bf8cb27b4b0657256842d61c6a56c8fa.
Tables1–5/PDF39–43 were visually inspected for overbars before authoring RTL.
The expression CSVs are independent transcriptions of manufacturer artifacts.
The oracle interpreter derives expectation vectors without reading RTL.

Original Figure17/PDF53 and Figure19/PDF54 supply multiply.csv: respectively
LDCT 00F + RPCT repeat unsigned multiply, and LDCT 00E + RPCT signed multiply
followed by signed final cycle with Cn=Z. Symbols R0/R1/R2 are instantiated as
actual register addresses0/1/2; the control-store base is a test parameter.
Both programs run on four actual native slices and actual Am2910 hardware.
No invented multiply program or shared instruction model is used for products.
Figure15/18 provide physical carry/Q/SIO/Z wiring and MSS sign correction.

## Correction of original Table5 printing

The 1978 special-E Gi/Z=LOW cell incorrectly prints complemented R despite
Table4 specifying addition. The [AMD 1979 Designer's Guide](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf),
PDF69/printed2-7, corrects that cell to R AND S. RTL and golden CSV use this
explicit manufacturer correction; it is not an inferred semantic repair.
