# Apple II copper topology and floating data bus

## Observation and external oracle

Comparison with Mike Willegal's independently traced revision-0
[copper CAD archive](https://www.willegal.net/appleii/A2rev0.zip) found that
our imported KiCad facts shorted the two physically distinct grounded-input
A2 NAND outputs into SOFT5, and omitted a grounded unused H14.6 output.
The independent pad fixture now records 83 ICs and 1,368 physical pads.
Its provenance and source label aliases are in the
[board ledger](../system/apple_ii/board/README.md).

Don Lancaster's *Enhancing Your Apple II and IIe*, Vol.2, Enhancement 13,
pp.196–198 ([scan](https://dokumen.pub/enhancing-your-apple-ii-and-iie-volume-2-1st-ed-9780672224256-0672224259.html)),
documents stray bus capacitance retaining the preceding video byte when
software reads an undriven I/O location, such as C020. Our ideal-Z board
boundary and unknown-bits-high CPU adapter returned ones instead. Historical
Vaporlock software depends on that retained value. This defect was discovered
from the external circuit/software description, not the existing board suite.

## Why the existing tests missed these defects

All generated connections came from one imported transcription. The generator
freshness check could only show internal consistency with that source. Both
soft-5 outputs are normally high, so boot/software tests could not detect an
unphysical short. The unused H14 output also did not change selected game data.

Monitor speaker/cassette routines use address side effects or only test D7;
they do not require the undriven lower bits to agree with the preceding video
byte. CPU instruction comparisons verified the supplied data, not board charge.
Firmware success therefore did not establish floating-bus correctness.

## Fix and verification

- Correct the two copper discrepancies, recording every changed pad in the
  manifest correction ledger. Use ideal supply strength for grounded H14.6;
  physical short-circuit current remains an explicit electrical limitation.
- Preserve charge on the actual D0..D7 slot nets through weak resolved feedback.
  No video fetch, memory block or address decoder is replaced. Unknown strong
  drive/contention invalidates charge; a known drive restores it.
- Compare all IC source net partitions, rejecting both split and shorted nets.
  The source fixture can be regenerated from a separately traced SHA-pinned
  file without reading imported pin nets or RTL.
- The physical floating-bus regression checks 5,632 known reads, D7-only inputs,
  slot drive, contention, recovery, CPU writes/RAM readback and RES preservation.
  Disabling retention makes the same C020 assertion fail.
- Re-run original Monitor/BASIC/video/cassette gates; exact outcomes are recorded
  in the [system report](../system/apple_ii/report/final_report.md).

## Prevention

`run_all.sh` now includes the independent all-IC copper check and the physical
floating-bus regression with its required negative control. Imported connectivity
and generated RTL agreement are never sufficient as independent wiring evidence.
Ideal rail/charge/leakage assumptions remain in the spec and inline RTL comments;
missing measured electrical agreement cannot be counted as a pass.
