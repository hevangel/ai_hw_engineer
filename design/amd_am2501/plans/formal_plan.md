# Formal plan: Am2501

Prove the documented six-CE and two-CE packages separately. After a first
parallel preset (assumed only at the first CP), all controls are arbitrary.
Compare against the 16-state manufacturer's diagram encoded as constant
successor/predecessor lookup tables. Prove preset priority, count-inhibit,
direction, wraparound, and combinational TC independent of PE/CE.

Physical CP is the formal clock; discrete sampled transitions are proved.
Pin-level simulation separately exercises idle clock levels and legal control
update windows. Cover upward and downward wrap, inhibit at TC, and preset
while CE is low to establish non-vacuity. Run BMC depth 24, induction, and
cover on each package. No power-up state is assumed for the actual counter.
