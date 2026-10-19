# Apple IIe functional platform verification

## Implementation

Original NMOS 6502 plus the actual MMU/IOU/PAL RTL; 64 KiB main and 64 KiB
auxiliary RAM; MMU row/column physical addressing and language-card banks;
encoded keyboard through IOU retiming/status; IOU-scanned video and pin-driven
character-ROM selection; local HTTP panel and captured master-clock signals.
Both original-ROM and enhanced-character artifacts are pinned and remain
ignored. No emulator executes instructions. See the specification for the
normalized cycle-level IOU adapter and power/reset sequencing.

## Observed checks

- Strict RTL Verilator lint passes without RTL warning waivers.
- Board-directed tests pass main/aux, ALTZP, 80STORE read-side PAGE2,
  language-card remap/write-protection, keyboard, Cxxx ROM and status.
- All 7,680 visible text-scanner addresses match an independent TRM layout
  formula; each CPU bus cycle spans exactly 14 master ticks.
- The bounded bus test passes both Verilator and uninstrumented xezim.
- New physical-address adapter formal BMC/prove/cover all pass; non-vacuous
  covers include both language-card banks. This is not whole-system ISA proof.
- Yosys process/optimization/memory inference and check -assert pass. RAM/ROM
  stay inferred; no physical implementation or technology mapping is claimed.
- Verilator executes the unchanged original IIe ROM, exact reset-vector and
  first-fetch checks, Apple ][ startup, keyboard-driven POKE 768=55,
  PRINT 6*7=42, PR#3 and PRINT 12345 through auxiliary/main 80-column RAM.
- Real-firmware RTL line coverage: 664/759 = 87.48 percent.
- HTTP end-to-end test passed real ROM startup, queued BASIC commands,
  80-column text ordering, a live PNG and 140-tick waveform, and rejection
  of a mismatched request Origin. Both Verilator and xezim/DPI backends
  also pass PNG dimensions/CRC/decompression, exact waveform phase counts
  and warm reset followed by PRINT 9*9=81.

## Escaped chip defects and diagnostics

Original ROM execution exposed C800 internal-ROM selection and read-side
C05x switch assumptions shared by prior RTL/reference/formal expectations.
The primary-manual corrections and regression cases are in the
[post-mortem](../../../failure_notes/2026-10-19-apple-iie-rom-switches.md).

Board xezim coverage instrumentation changes RAM readback relative to the
same uninstrumented test. No root-cause claim is made. The strict failing
configuration is retained by reproduce_xezim_coverage.sh; normal xezim
functional tests remain mandatory and Verilator supplies line coverage.
See the [diagnostic note](../../../failure_notes/2026-10-19-apple-iie-xezim-coverage.md).

## Limits

Functional CPU transfers omit NMOS dummy/page-cross timing. IOU decoding is
normalized to its existing cycle-level interface. The master clock and PAL
retain their documented abstraction limits. This is a 128 KiB extended-memory
configuration, not a claim about base-IIe installed RAM. Enhanced glyph data
is an external representation; original 1983 character-mask identity is not
certified. Digital lores/hires preview does not model analog artifact color,
half-dot delay, double-hires or composite voltages. Disk II, slot cards,
paddle/tape electronics and audio playback are absent. Open-bus low bits use
the last scanner byte; leakage and electrical contention are not modeled.

## Independent engine and chip evidence

xezim 0.11.0 (6558a1e) executes the original system ROM, checks exact reset
and first-fetch addresses, delivers every key through C000/C010 and observes
physical main RAM 0300=55 at bus cycle 170,447 (64,658 opcode fetches).
The read-only observation port is explicitly selected for each transaction;
the isolated stale constant-address read remains a documented reproducer.

The corrected MMU full flow passes 57,208 checks per simulator; IOU passes
30,831,387 Verilator / 30,831,415 xezim checks. Both pass formal BMC/prove/cover,
coverage and synthesis; added covers exercise the corrected read-switch and
internal-ROM cases. IOU statement/branch coverage is 100 percent and toggle
coverage is 99.47 percent. The CPU and PAL RTL are unchanged.

Commands: system/apple_iie/scripts/run_all.sh and, separately,
SIMULATOR=xezim PANEL_TIMEOUT=900 sh system/apple_iie/scripts/run_host_test.sh.
The chip regressions use their existing scripts/run_all.sh. Toolchain:
Verilator 5.052, xezim 0.11.0, Yosys 0.69, SBY and Z3 from the pinned project
image. Detailed logs, coverage data and exit markers remain in ignored work/.

Final complete system acceptance on 2026-10-19: PASS (run_all.sh exit 0).
The separate xezim/DPI HTTP flow also exits 0. Strict simulator-discrepancy
reproducers are diagnostic tools outside the passing acceptance suite.
