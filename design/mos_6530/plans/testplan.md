# Test plan

Read all original ROM bytes through both actual mask instances. Write and
read both 64-byte RAMs, verify retention/ROM write protection, exhaustive
unexpanded KIM memory map and mutually exclusive data enables. Test all
DDR masks, both GPIO ports, select-pin ownership, register mirrors and
PB7 timer versus GPIO drive. Sweep all four timer divisors and all byte
loads using elapsed-time equations in Verilator; representative loads in
xezim. Test separate status/count reads, simultaneous expiry/acknowledgment,
post-expiry disable, prescaler restoration, wrap and independent chip state.
Run manufacturer monitor firmware as a separate regression with observed
port/RAM/ROM activity and explicit boot checkpoints, not just a cycle limit.
