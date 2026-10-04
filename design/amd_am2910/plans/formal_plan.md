# Am2910 formal plan

No fabricated reset. Constrain only initial legal depth. Independently check
Y-source selection, decoder one-hot active-low, output-enable, FULL, PC
increment/retention, counter priority and watched-stack-slot write/hold.
Use a symbolic anyconst stack address. Run BMC, unbounded PDR and cover.
Covers require all opcodes plus full overflow, empty underflow, every TWB
outcome, RLD overriding decrement and wraparound PC with OE released.
