# Motorola MC6800

The MC6800 is Motorola's first general-purpose 8-bit microprocessor and
the founding member of the M6800 Microcomputer System: two 8-bit
accumulators, a 16-bit index register and stack pointer, 72 instructions
in six addressing modes, maskable IRQ and non-maskable NMI with a 7-byte
stacked interrupt frame, and a 64 KiB flat address space clocked at up to
1 MHz. It anchored the MEK6800D2 kit, the MIKBUG/MINIBUG ROM monitors and
early embedded designs, and its architecture carries forward through the
6801/6301/68HC11 family.

Motorola announced the M6800 Microcomputer System in **March 1974** and
had it in full production by the end of that year ([Wikipedia,
Motorola 6800](https://en.wikipedia.org/wiki/Motorola_6800)); secondary
retellings differ on the exact announcement day within March 1974 and no
month-level claim beyond "March 1974" is made here. Technical behavior
follows the [M6800 Programming Reference Manual, M68PRM(D), November
1976](https://bitsavers.trailing-edge.com/components/motorola/6800/Motorola_M6800_Programming_Reference_Manual_M68PRM(D)_Nov76.pdf)
(bitsavers), whose Appendix A per-instruction flag definitions and Table
3-1 opcode matrix are the design's primary sources.

## This design

- `spec/spec.md` — architectural contract, assumption ledger.
- `src/motorola_6800.sv` — full documented ISA (197 codes) on a
  functional transaction bus (one transfer per clock).
- `scripts/make_isa_vectors.py` — independent PRM-derived Python ISS that
  generates the full-ISA comparison vectors.
- `tb/tb_top.sv` — instruction-boundary vector replay + memory compare.
- `references/hakanrw_mc6800/` + `scripts/assemble_thirdparty.py` +
  `tb/tb_thirdparty.sv` — 50 vendored third-party self-checking test
  programs ([hakanrw/mc6800](https://github.com/hakanrw/mc6800)) run as
  the real-software gate.
- `formal/motorola_6800.sby` — BMC/prove/cover properties.
- `report/final_report.md` — verification results.

Verification status: all gates pass (see the report); two shared
RTL/ISS misreadings caught by the third-party suite are documented in
`failure_notes/2026-10-23-motorola6800-subtract-carry-and-acc-select.md`.
