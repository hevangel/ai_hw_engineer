# Formal plan

Initial reset assumption, arbitrary subsequent inputs. Prove nonoverlapping
default masks, bus enable, ROM immutability/read mapping, arbitrary-address
RAM retention, register writes/isolation, reserved output ownership and
timer/PB7 state updates. Cover RAM readback, ROM access, enabled and disabled
expiry, GPIO override and post-expiry acknowledgment. This proves the
sampled contract; physical timing and firmware are separate obligations.
