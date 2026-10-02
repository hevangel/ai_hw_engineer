# Formal verification plan

BMC, unbounded safety prove and non-vacuity cover tasks use symbolic inputs, initial reset and legal ownership (HLDA held until HRQ drops). READY need not eventually rise.

Prove one-hot normalized DACK, ownership before strobes/commit, cascade/verify and memory-copy suppression, wait stability, exact normal address/count updates and EOP mask/reload. Check symbolic channel banks without reducing 16-bit counts.

Cover commits on all channels, wait, verify with READY low, cascade, TC, reload and both memory-copy halves. These are safety properties, not complete behavioral equivalence or liveness under a permanently stalled peripheral.

Only cover uses `intel_8237_cover_setup.sv`: eight symbolic cases execute actual CPU mode/command/unmask writes after reset, then request/grant and a finite READY stall. This avoids costly arbitrary programming searches. Safety BMC/prove do not include those constraints and retain arbitrary CPU programming and readiness.
