# Original AMD setup programs

STUP (33 bytes) and SDMA (132 bytes) are transcribed from the published object
columns of Figures20/21 in the 1979 AMD Designer's Guide PDF311–314, printed
5-37–5-40. They retain original bytes, addresses and branch targets. STUP's
literal command62 differs from the printed binary operand60; its literal
count07 differs from operand7F. Both object values are visibly printed in the
scan. The regression runs the actual objects, documents these printing errors,
and expects eight transfers rather than quietly patching the source to128.

SDMA receives five inline parameters following its CALL: mode, low/high address
and low/high count. Its XTHL/POP/PCHL flow must return exactly after those bytes,
without padding or relaxed PCs. Its four branch-table destinations are
3020/3037/304e/3065 and the table resides at307c. A pinned external Superzazu
8080 model supplies instruction semantics, with the independently documented
Am9080A ANA auxiliary-carry adapter for ANI03 (AMD clears AC; original Intel
8080 instead computes an operand-dependent AC). The CPU oracle is separate
from independently checked DMA memory/peripheral streams.

[Manufacturer source](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf).
