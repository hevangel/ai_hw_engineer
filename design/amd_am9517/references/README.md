# Am9517 source and implementation assessment

Primary original AMD references:

- [1979 AMD Designer's Guide](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf),
  PDF245–260 (printed4-43–4-58) and PDF297–316 (printed5-23–5-42).
  Native register map, masks, types and control bits are PDF250–252/305–309;
  HACK-time priority is explicit at PDF303/307; programming while waiting is
  explicit at PDF309. Original STUP/SDMA objects are PDF311–314.
- [Electronics, January19,1978](https://www.worldradiohistory.com/Archive-Electronics/70s/78/Electronics-1978-01-19.pdf),
  cover date PDF1, original AMD announcement PDF77–78. This supplies a public
  marketing bound; it does not establish exact commercial shipment timing.
- [Compatible Intersil 82C37A datasheet](https://www.renesas.com/en/document/dst/82c37a-datasheet)
  supplies the explicitly qualified source-count clarification, not proof of
  an undocumented original AMD silicon behavior.

Cache hashes/pages are maintained in the [AMD manifest](../../../references/amd/README.md).
Scans were visually inspected for codes, bit assignments and object bytes,
including printed errors; OCR alone is not treated as authoritative.

## Reuse audit

The project-owned [Intel8237A implementation](../../intel_8237/README.md) is reused
as an arithmetic/register/service-state starting point. The Am9517 is its own
module with no runtime dependency on that RTL. The following independent AMD
source findings change behavior and associated expectations:

| Item | Original AMD rule | Adaptation |
|---|---|---|
| RESET | Active HIGH, asynchronous, PDF302 | Native reset port and asynchronous control/channel reset |
| Register E | Illegal write, Figure13/PDF306 | No Intel clear-all-mask command; deterministic invalid-access adapter only |
| Status requests | Hardware DREQ inputs, PDF306 | Exclude software requests from status high nibble |
| Arbitration | First action on HACK, PDF307 | Resolve current requests at grant rather than latch an earlier selection |
| Pending programming | Legal when HACK LOW even with HREQ HIGH, PDF309 | Enable register bus while waiting for grant |
| Disable | CommandC2 inhibits HREQ, PDF307 | Pending HREQ obeys disable |
| Memory copy initiation | Software request channel0, PDF306 | Hardware DREQ0 does not initiate copying |

Unspecified reset channel programming, invalid-access outputs, source-count
reload and external-EOP phase conventions remain explicit assumptions. They
are not presented as newly discovered original hardware details.

## Printed-source discrepancies

Application Figure15/PDF307 reverses source-hold bit labels; its adjacent prose
and original datasheet PDF250 consistently specify bit1=1 inhibits advancement.
Follow those agreeing sources. STUP's object command62 disagrees with binary
operand60; its count07 disagrees with operand7F. Published object bytes are
preserved and the actual eight-transfer reconstruction is checked. SDMA's
branch table and exact return after its five inline parameter bytes are retained.

The manufacturer's prose describes count reaching zero without specifying the
edge relative to decrement. N-1 programming/underflow is the qualified compatible
convention, exercised by original firmware and the complete65536-transfer test.
No physical Am9517 measurement is claimed to resolve that textual ambiguity.

## Independent CPU evidence

The original software runs on Am9080A and uses the independently pinned MIT
[Superzazu 8080 emulator](../../amd_am9080/references/README.md), with
an explicit manufacturer-derived AMD ANA/ANI AC-clear adapter as documented in
[Am9080A's specification](../../amd_am9080/spec/spec.md). This narrow adapter
changes no instruction control or PC behavior. Exact fetches, retirements, stack
writes and I/O are checked; DMA streams use separate address/count/strobe/data
expectations. Object transcriptions are immutable and integrity-checked.
