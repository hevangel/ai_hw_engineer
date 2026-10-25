# Intel 8087 source provenance

- Intel, [The 8086 Family User's Manual, Numerics Supplement, July 1980](https://mark-ogden.uk/files/intel/publications/121586-001%20The%208086%20Family%20Users%20Manual%20Numerics%20Supplement-Jul80.pdf),
  order 121586-001. Printed S.2–S.7 define architecture and instructions;
  S.8–S.10 contain original software; appendix B defines exceptions; the
  closing encoding chart defines ESC bytes. The original scan is archived in
  [shared scan](../../../references/intel8087.pdf); the clean searchable extraction is [manual.txt](manual.txt).
  Download SHA-256:
  `d2d8557a8e9c24cdc4613ea5d51cd3cf745fbd586c6eaab1a1af1ccfc977aa04`.
- Intel authors, [The INTEL 8087 Numeric Data Processor, National Computer
  Conference 1980](https://kib.kiev.ua/x86docs/Intel/486/8087.pdf). This
  contemporary publication and the dated Intel manual establish availability
  in **1980**. An exact announcement month is not asserted.
- Intel, [8087 datasheet, 205835-007](https://datasheets.chipdb.org/Intel/x86/808x/datashts/8087/205835-007.pdf),
  table 4a pins the FPREM quotient mapping: C0=Q2, C3=Q1, C1=Q0.
  The supplement's prose lists condition bits without that explicit mapping.

Independent arithmetic expectations use the build host's x87 `long double`
instructions (64-bit significand, 15-bit exponent), not a model derived from
RTL. Modern x87 differences are excluded explicitly in the specification.
Manufacturer program provenance and exact transcribed operations are retained
with the regression. Original scan files are centralized under `references/`; the design folder retains searchable text and behavior summaries.
