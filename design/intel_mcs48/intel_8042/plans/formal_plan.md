# Intel 8042 formal plan

`formal/upi42_core.sby` checks the inline `ifdef FORMAL` properties of
`src/upi42_core.sv`. The program ROM, host bus, ports and test inputs are
unconstrained, so the properties hold for any program and any host.

Proved (abc pdr, unbounded):
- the sequencer uses only its three states;
- every instruction or vector retires within two machine cycles;
- a vector cycle is always inside an interrupt, and no interrupt is taken
  while one is in progress;
- IBF has priority over the timer;
- a completed host write leaves IBF set;
- the prescaler changes only in timer mode or on STRT T.

Covered (smtbmc yices): IBF vector, timer vector, RETR leaving the
interrupt, stack wrap by CALL, and OUT DBB setting OBF.

Instruction semantics are checked by lockstep simulation against the
reference model, not formally.
