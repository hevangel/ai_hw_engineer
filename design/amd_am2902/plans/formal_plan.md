# Formal plan

Arbitrary nine input bits. Reference each expected carry using the ripple
recurrence. Aggregate generate is recurrence with input zero; aggregate
propagate is logical AND across all decoded inputs. Assert carry consistency
with the aggregate fourth carry and Cn-independence of group outputs.
Run depth-2 BMC, unbounded induction and reachable covers for kill, full
propagation with both Cn levels, generation and generation with disabled
propagation. Combinational design needs no reset or initial assumption.
