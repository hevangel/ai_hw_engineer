# Protected HLT privilege

## Contract

`HLT` is a trusted instruction. In protected mode it may execute only at
CPL 0, independent of IOPL. If PE is set and CPL is nonzero, raise restartable
`#GP(0)` at the first byte of the instruction. The faulting instruction must
not retire or set the halt latch. Real-address mode remains unrestricted by
this privilege check, and protected CPL 0 retains the existing halt behavior.

The primary source is Intel's
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
§3.11 and the HLT instruction entry. Intel lists HLT among protected-mode
trusted instructions and specifies `#GP(0)` when CPL is not 0.

## Directed evidence

Check CPL 0 at all four IOPL values and CPL 1, 2 and 3 at all IOPL values, in
both READY modes. Allowed HLT must retire and halt at its exact successor.
Denied HLT must deliver restartable `#GP(0)` with the instruction-start CS:IP,
saved FLAGS and SP, without retirement or entering HALT. Existing real-mode
HLT regressions must continue to pass.

The privilege check is independent of IOPL. Task switching, native halt pin
timing and interrupt wake timing remain separate requirements.
