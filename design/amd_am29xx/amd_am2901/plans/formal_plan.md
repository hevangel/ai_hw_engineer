# Formal plan

Combinational ALU: arbitrary R, S, carry and function. Independently expanded
manufacturer equations specify all F/status pins; prove and reach all functions,
carry, arithmetic overflow and zero. No reset assumption for combinational logic.

Storage: native clock with multiclock conversion; arbitrary initial RAM/Q;
an anyconst watched address. Constrain only timing-valid controls at transitions,
track written state, prove closed read-latch retention, selected-word writes,
unselected-word retention, Q edge updates, output-enable and shift direction.
Run BMC, unbounded proof and cover; uninitialized RAM must not make the proof
vacuous. Report what is proved rather than implying full-system equivalence.

The FORMAL write-data cut breaks a netlist-only structural latch loop; its
value is constrained equal to the actual RTL write equation at every global
step. This is an equality relation, not an unconstrained abstraction of writes.
