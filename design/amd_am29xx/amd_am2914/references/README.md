# Manufacturer artifacts and interpretation

`instructions.csv` transcribes the16 native instruction effects in the 1979
TableI/PDF168 and detailed table/functional descriptions on PDF185–189.
It was authored before RTL. Descriptive actions are interpreted independently
for the golden model; no implementation source is read. The [specification](../spec/spec.md)
identifies clock-phase adaptation and the explicit source rules used where
drawings are ambiguous.

Primary scans:

- [1979 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf):
  device PDF166–173, original interrupt/cascade application PDF174–184,
  detailed gates PDF185–190. Figure4/PDF177 gives the actual save/vector/
  clear/service/restore operation sequence.
- [January1987 AMD datasheet](https://bitsavers.trailing-edge.com/components/amd/bitslice/_dataSheets/1987_2914.pdf):
  PDF5 explicitly states sticky SV until master clear/status load and native
  edge-triggered sampling, despite an abbreviated level-triggered sentence
  in the opening summary. Native edge contract follows the pin/functional
  description, consistent with the original source.
