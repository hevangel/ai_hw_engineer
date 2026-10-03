# Formal plan

An arbitrary constant 10-bit watch address proves the last selected normal-
supply write is returned on later reads, even across other-address writes,
deselected write pulses and standby transitions. Only the oracle's written
flag is initialized; DUT storage has no initial constraint. Manufacturer
read/write and standby descriptions derive the oracle independently.

Check output-enable and validity decoding in all modes, and selected-write
feedthrough. Covers reach both stored values, unrelated-address write before
readback, standby entry/recovery and the invalid selected-standby mask.
Multiclock lowering represents asynchronous latches on the global formal
timebase. ABC BMC/PDR establishes safety; Z3 cover checks non-vacuity.
