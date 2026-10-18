# Verification plan and proof boundary

## Simulation

`tb/test_8087.cpp` drives public ESC and memory interfaces. Every command has
a watchdog; inserted two-cycle stalls require stable valid, address,
direction and write data. Memory addresses wrap at twenty bits.

Independent expectations use actual host x87: 7,680 ADD/MUL/SUB/DIV cases
across 24/53/64-bit precision and all rounding modes, FRNDINT/FIST halfway
cases, real32 stores and 180 square roots. The oracle covers shared finite
numeric behavior; modern x87 exceptions do not judge original 8087 behavior.

Manufacturer-derived directed cases cover FINIT=03FFh, FENI/FDISI, IR/INT,
WAIT override, projective/affine infinity, NaNs, unnormal operands,
before/after trap retirement, wrapped exponents, gradual underflow, stack
faults, TOP wrap, seven memory formats, physical address wrap, 94-byte
save/restore and environment transfer. Original Intel ARRSUM is mandatory;
see `tb/software.md` for the replay boundary.

Transcendental samples use independent C library `long double` functions
with 4e-18 relative tolerance. This is finite approximation evidence, not
an exhaustive error bound or comparison with original 8087 silicon.

## Formal

The real core runs a reduced D9 alphabet: FLD1, FLDZ, FINCSTP, FDECSTP,
FNOP and FSTCW. Assertions check stalled requests and write data, pointer
wrap, unchanged tags/registers for pointer-only operations, reserved status
bit 6, idle stability and ready/state consistency. BMC checks six clocks;
temporal induction proves these invariants beyond that bound. Separate
covers witness eight pushes through TOP wrap and stalled/completed FSTCW.

`FORMAL_CONTROL` explicitly replaces conversion with data abstraction and
numeric units with unconstrained responses. Numerical values, rounding,
exception computation, other opcodes and save/restore are **not formally
proved**. Those claims depend on simulation. Alphabet reduction follows
unrestricted solver timeouts; no assertion was weakened after a counterexample.

## Synthesis

Yosys checks the unabstracted hierarchy, lowers processes, optimizes, checks
structure and emits a word-level JSON netlist. This establishes synthesizable
constructs and structural integrity. It does not establish mapped area,
timing closure or physical implementation. Combinational division and square
root need pipelining or iterative replacement for frequency constraints.
