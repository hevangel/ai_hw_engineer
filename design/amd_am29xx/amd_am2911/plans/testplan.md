# Test plan

Use manufacturer Figure 6's top-first rotating stack, independently of the
shared RTL engine's circular pointer. Register expectation is D on an enabled
edge. Test live D changes with register enable disabled, then enable load
and select held register. No R/OR pins may appear in the wrapper.

Sweep all 256 select/control combinations, sixteen PC/value patterns and
stateful random inputs, checking all four stack words after every case through
actual selections/pops. Execute manufacturer Figures 7/8 on three actual
Am2911 slices, with literal executed/next-address lists and poisoned unused
microstore entries. Boot through actual controls; never force initial state.
