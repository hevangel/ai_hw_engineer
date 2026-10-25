# Test plan

Initialize via ZERO, register load and four real pushes; never force internals.
Reference-model transitions come from original Figure 6, using a top-first
rotating list instead of the DUT's circular pointer. Sweep all select, stack,
register enable, ZERO, OE and carry combinations; vary all direct/register/OR
bits and counter values. Check pre-edge Y/carry, next counter, register and
all four retained stack words using visible source selections.

Three-slice 12-bit historical microstore executes manufacturer Figures 7/8,
including pipeline fetch latency and a one-word nested subroutine. Check each
executed address, selected next address and pushed return; poison every other
microstore entry. Exercise wrap across nibble and full-address boundaries,
four-deep linkage, repeat Cn=0, disabled OE, OR multiway branch and ZERO priority.
