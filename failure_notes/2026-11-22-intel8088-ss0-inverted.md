# 8088 SS0 status pin driven inverted — 2026-11-22

## What broke and how it was found

An external code review of `design/intel_8086_8088/intel_8088` at `dfdc0db`
([ai_hw_engineer#288](https://github.com/hevangel/ai_hw_engineer/issues/288))
sampled IO/M, DT/R and SS0 in T2 of each bus cycle type and compared them
with the 8088 data sheet. SS0 had the wrong level in all six cycle types, so
read-memory decoded as code access, writes as passive, and interrupt
acknowledge as an I/O read. In maximum mode pin 34 toggled, although the
data sheet says it is always high. While the bus was idle, IO/M and DT/R
kept the last cycle's values, so a halt decoded as whatever cycle came
before it. No system in the repository connects the pin, so nothing failed
in use.

## Root cause and why verification missed it

The RTL drove `sso_n_o = !status_o[0]`. The data sheet's own words —
"logically equivalent to S0" (p. B-33), "equivalent to S0 in the maximum
mode" (hardware reference p. 4-11) — were read as "carries the S0
information", and the port was named and modelled as active-low
(`sso_n_o`). `status_o` already held pin levels (passive 111, code access
100), so the inversion was not needed. The data sheet's table of pin levels
settles the question directly.

Every check shared that reading:

- the native bench required `sso_n_o == !(status_o & 1)`;
- the UVM scoreboard checked the same formula;
- the formal covers witnessed read with the pin low and write with the pin
  high;
- the spec text itself said "low during reads, high during writes".

None of them wrote out the data sheet's eight-row table. The idle IO/M and
DT/R levels were never checked at all, because every pin check ran only
inside T2–T4.

## Fix and re-verification

`ss0_o = min_mode_i ? status_o[0] : 1'b1`. Outside a bus cycle, IO/M and
DT/R give the data sheet's PASSIVE (011), or HALT (111) while halted.
Minimum-mode ALE for HALT follows the HALT status by one clock (p. B-32).
The native bench, UVM scoreboard and BIU formal properties now check the
table as literal three-bit values in T1/T2 and while idle. A directed case
observes all six cycle types and HALT. It fails on the previous bus unit
(`idle IO/M DT/R SS0=0 is not PASSIVE/HALT`) and passes on the fix. The
review's Q1 and Q2 probes match the table and show pin 34 constant high.
Results are in `design/intel_8086_8088/intel_8088/report/final_report.md`.

## Prevention

- A pin whose meaning comes from a data sheet table is checked against that
  table written out as literal values, never against an expression that
  mirrors the RTL.
- Pins that carry a status decode are checked in every bus phase, including
  idle and halt, not only inside a cycle.
- An active-low suffix (`_n`) on a status port must agree with the data
  sheet's table of pin levels.
