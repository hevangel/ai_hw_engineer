# Implementation plan: Ricoh 5A22

1. Spec and timing table ([spec](../spec/spec.md)).
2. H/V counters with the documented line-length exceptions.
3. Bus sequencer with four owners (CPU, refresh, DMA, HDMA); the CPU cycle
   length is decoded from the address the core presents.
4. DMA/HDMA engine with separate channel and byte-index state, 8-clock units.
5. Registers, multiply/divide, NMI/IRQ, joypad and auto-read.
6. Verify in `system/snes` with Peter Lemon's ROMs against their reference
   screenshots; a directed testbench checks timing positions in isolation.
