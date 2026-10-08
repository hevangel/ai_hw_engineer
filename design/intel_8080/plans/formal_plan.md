# Intel 8080 formal plan

ALU assertions derive equations from the independently authored pinned Intel
C oracle. Prove all operation results and flags, with reachable covers for
all operations and both outcomes of Intel ANA's AC bit. Run BMC, induction
and cover; no AMD AC correction is applied.

Controller assertions prove reset and retention, stable transactions and
architecture under READY stalls, suppression under HOLD/fault, legal status
and space decode, and retirement boundaries. Reachable covers exercise
memory read/write, I/O, wait, HOLD, HALT, interrupt and fault.

These controller properties do not prove complete instruction semantics;
independent opcode and historical-software regressions provide that check.
