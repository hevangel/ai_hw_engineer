# Formal plan

Prove the actual Am2911 wrapper, not an unconstrained Am2909. The shared
engine's source/register/counter/stack assertions apply with R=D and OR=0.
Variant compilation changes only the ZERO cover from OR=15 to the physically
available OR=0. All source, push/pop, repeat, ZERO and disabled-OE carry covers
must remain reachable. Run depth-16 BMC, unbounded PDR and cover; no reset
or power-up-state assumptions.
