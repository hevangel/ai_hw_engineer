# 6507 implementation plan

1. Source the reduced package and internal IRQ/NMI ties; specify the 16-bit
   internal address versus 13-bit physical bus before RTL.
2. Reuse the verified native NMOS engine with decimal mode enabled and
   unavailable interrupt/SO inputs inactive. Expose debug separately.
3. Add formal physical-address mapping and tied-input properties, reachable
   high-address alias/reset/BRK covers, and exact bus simulation for reset
   aliases, indexed crossing, writes, BRK and logical PC wrap.
4. Run original KIM-1 monitor through the 6507 interface in Verilator/xezim.
   Preserve exact reset instruction checkpoints and ordered display output.
5. Run strict lint, formal and synthesis. Publish actual measured results
   and remaining revision/clock/Atari integration assumptions. Keep the
   shared native engine regression in this design's complete flow.
