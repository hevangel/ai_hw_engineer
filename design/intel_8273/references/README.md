# Reference provenance

- [intel_8273.pdf](intel_8273.pdf): Intel order 210479-004, October 1992;
  33 technical pages plus Rochester Electronics cover, downloaded from
  [Octopart](https://datasheet.octopart.com/P8273-Intel-datasheet-38976656.pdf).
  PDF index 6 gives register decoding, 14–16 status/results, 18–25 commands,
  9–11 serial timing and DPLL. The reset opcodes are AND masks, not bit-clear masks.
- [Shared 1981 handbook](../../../references/1981_Intel_Peripheral_Design_Handbook.pdf):
  Intel's original Peripheral Design Handbook, saved at the user's request from
  [Bitsavers' mirror](https://bitsavers.trailing-edge.com/components/intel/_dataBooks/1981_Intel_Peripheral_Design_Handbook.pdf).
- [Intel advertisement, Electronic Design, November 22, 1977](https://device.report/m/8bc5b6376694b97e23c2f7405d8292f666953225fb3eb6506aa146bfc391ae7c):
  lists the 8273 with announced fourth-quarter 1977 availability. The exact
  shipment date remains unestablished; the index uses 1977*.
- [RFC 1662](https://www.rfc-editor.org/rfc/rfc1662.html), sections 3 and 5,
  appendix C: independent HDLC bit ordering, five-one zero insertion, reflected
  CRC-16 initialization/complement, low-byte-first FCS and F0B8 residue. PPP octet
  escaping and PPP-specific packet semantics are not used for the Intel controller.
- [frames.txt](frames.txt): 44 deterministic complete-byte bodies and their good
  and damaged-FCS bitstreams, created by [generate_vectors.py](../scripts/generate_vectors.py).
  Each record starts with body length, good bit count and bad bit count, followed
  by body octets in hex, good bits and corrupt bits. The generator never reads RTL.

The CRC oracle uses Python `binascii.crc_hqx` (an independently maintained C
implementation), reflecting input bytes and the output to obtain RFC ordering.
Its startup checks pin `123456789` to 906E and every valid body+FCS to the F0B8
raw residue. This differs structurally from the RTL serial feedback loop.
The generator also writes a maximum-length frame into ignored `work/sim/` as
packed 32-bit wire words. The formal Rx cover's supervisory frame is 42 13
8B 58, enclosed by 7E flags, from the same independent oracle.

Source descriptions are paraphrased; full archived manufacturer PDFs retain
their original content and notices.
