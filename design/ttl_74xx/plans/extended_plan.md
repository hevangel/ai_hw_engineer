# Extended numbered 74-series implementation plan

The user extended scope above 74299 on 2026-10-20. There is no numeric upper
limit. Include all numbered classic larger-package and wide-bus catalog entries,
including four-, five- and six-digit function suffixes. Small-footprint 1G/2G/3G
names and electrical-family substitutions are not additional numbered functions.
Preserve distinct L/H/LS/S functions. Do not invent unassigned numbers.

1. Freeze the complete selected inventory, including missing implementations.
2. Write a specification for every additional entry before adding its RTL.
3. Adapt available MIT baseline models; retain explicit normalized contracts.
4. Reject generic placeholders, writable ROM substitutes and missing digital
   functions (including boundary scan omitted from JTAG parts).
5. Exercise all implemented modules with strict lint, self-checking simulation
   and Yosys synthesis. Strengthen memory tests and two-clock shift/storage tests.
6. Publish coverage and missing-part reasons. Passing tools on the implemented
   subset must never report the entire requested library as complete.

Manufacturing dates remain unknown unless established from a dated source.
RC one-shots, VCO/PLL oscillation, analog conversion/switching and electrical-only
functions are excluded by the user's pure-digital scope. Digital counters remain
in scope even when their packages also contain oscillator circuitry; models take
an external digital clock and document this assumption.
