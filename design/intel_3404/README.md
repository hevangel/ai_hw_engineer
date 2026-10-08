# Intel 3404

The Intel 3404 is a high-speed 6-bit latch in Schottky bipolar TTL:
six inverting latch stages organized as independent 4-bit and 2-bit
sections, each with its own write enable. While a write enable is low
its section acts as a high-speed inverter (transparent); the rising edge
stores, and a high enable holds. Data-to-output delay is 12 ns maximum
over 0-75 °C.

First introduced: **1973***, the earliest located dated Intel
documentation being the [November 1973 MCS-8 Users Manual](../../../references/intel_mcs8_users_manual_nov1973.pdf),
which uses 3404s throughout the SIM8-01; the manual's own service note
that SIM8-01 boards built prior to October 1972 require modification
shows the module was already in field use, so the latch's availability
likely predates that document. The uncertainty is retained rather than
guessed; no month-level claim is made.

Why it matters here: the 3404 is the other dedicated support chip of the
MCS-8 (8008) chip set. The SIM8-01 stores the 8008's time-multiplexed
lower address byte (state T1) and higher address byte with the CC0/CC1
control bits (state T2) in 3404 latches "provided to all memories", and
under the INP instruction the CPU's flag flip-flops are stored in a
single 3404 (package A43) — the four flags fitting the 4-bit section.
Together with the [3205 decoder](../intel_3205/README.md) it completes
the 8008 board beyond the CPU itself; the [8008 design](../intel_8008/README.md)
is the companion processor core in this repository.

Technical behavior follows the combined [Intel 3205/3404 data sheet](../../../references/intel_3205_3404_datasheet.pdf)
(16-pin DIP; the sheet's D.C. table distinguishes write enable pin 7,
−1.0 mA input load, from write enable pin 15, −0.5 mA — consistent with
four gated inputs versus two). This repository implements the latch as a
synchronous single-clock block with a reset artifact; the assumption
ledger in the [specification](spec/spec.md) records where the
reconstruction deviates from the asynchronous physical part.

**Verified.** Verilator lint, formal (bmc/prove/cover, non-vacuous),
directed + 5000-cycle random simulation in Verilator and xezim, 100%
statement/branch/toggle code coverage and Yosys synthesis all pass —
see the [validation report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Source manifest](references/README.md)
