# Test plan: Am3101

Use a 16-word external expected memory initialized only by real DUT writes.
For each of 16 addresses and 16 data words, exercise all CS/W modes, checking
that only selected writes modify memory and reads invert it. After every
control combination scan all 16 addresses to catch aliasing and corruption
of other words. Never compare unwritten power-up data with an invented zero.

Hold selected W LOW and vary D repeatedly, checking that storage follows
the latest value after write closes. Exercise both W-controlled and
CS-controlled write windows with valid setup/hold and check deselected-write
outputs are explicitly invalid. Wire two actual Am3101s as a 32x4 bank,
combining their open-collector output levels with AND. Read every banked
address and both-disabled output release.

The bench is deterministic and fatal on errors, uses direct pin transactions,
and requires exact transition/read/cascade coverage counts plus a pass marker.
These discrete memory pins have no synchronous bus or UVM protocol interface.
