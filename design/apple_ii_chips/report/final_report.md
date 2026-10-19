# Package verification

- 29 digital package regressions passed with Xezim in four-state mode.
- One analog package regression passed with Icarus 12.0-3.
- 16 combinational models synthesized and passed Yosys `check -assert`.
- The integrated digital motherboard passed Verilator 5.052 lint with
  documented exceptions for physical open/unused pins, pullups, and bus feedback.
- System testing exercised three physical DRAM banks and original Monitor
  keyboard deposit/examine commands. See the
  [system evidence](../../../system/apple_ii/report/final_report.md).

The digital tests cover exhaustive combinational cases, counters, latches,
parallel loads, both shift directions, J/K serial inputs, clock inhibit,
asynchronous clear/preset release, ROM address/data pins, DRAM early/late
writes, and enabled/disabled bus directions. Analog tests check thresholds,
trigger rearming, open collectors, and amplifier slew/output limits.
Every script requires an explicit success marker.

No formal proofs or analog/DRAM-event synthesis are claimed. Whole-board
electrical timing, original font content, cassette/video waveforms, device
tolerances, and power-up behavior still need validation. Historical software
uses an external transistor CPU reference; it does not complete the authored
6502 RTL. The assumption ledgers describe the limits on sign-off.
