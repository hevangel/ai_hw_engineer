# String execution extension

Status: implemented functional extension; verification results are recorded in
the report. This specification preceded RTL. Sources are
Intel 210498-005 sections 3.7.2 and 4.1, and Appendix B entries for CMPS, INS,
LODS, MOVS, OUTS, REP, SCAS and STOS. The manual is linked in the chip README.

## Single elements

Support byte/word MOVS A4/A5, CMPS A6/A7, STOS AA/AB, LODS AC/AD, SCAS AE/AF,
INS 6C/6D and OUTS 6E/6F. Source memory uses DS:SI and accepts segment
overrides. Destination memory uses ES:DI and cannot be overridden. INS uses
DX as its port and ES:DI as destination; OUTS uses source memory and DX.
MOVS copies source to destination. LODS replaces AL or AX; STOS stores AL or
AX. CMPS sets arithmetic flags for source minus destination, while SCAS sets
them for AL/AX minus destination. Other string operations preserve flags.

Advance each used pointer by one for bytes or two for words, subtracting
instead when DF=1. Pointer arithmetic wraps at 16 bits. Single-element forms
leave CX unchanged. Byte offset FFFF is legal; a word element at FFFF uses the
current operand-limit diagnostic until architectural limit faults are added.
Each element checks its memory operands before starting its data transactions.
This diagnostic policy does not establish native I/O/fault bus priority.

## Repeat and partial progress

Implement the documented F3 REP forms for MOVS/STOS/INS/OUTS and F3 REPE/F2
REPNE for CMPS/SCAS. Resolve other prefix/opcode combinations against independent
286 evidence before claiming them supported. Segment and repeat prefixes are
part of the original instruction PC and ten-byte instruction length.

CX=0 completes with no element access, pointer/flag change or count decrement.
Otherwise perform an element, advance its pointers and decrement CX without
altering flags. Comparison repetition checks the newly computed ZF after that
element: REPE stops for ZF=0, REPNE for ZF=1. Initial ZF never suppresses the
first comparison. Zero CX terminates either form. Retire once on completion.

Completed elements are architectural partial progress even before the repeated
instruction retires. Expose a distinct element-completion observation for tests
and assertions; permit register/flag changes only at that boundary, retirement
or event delivery. An interrupt/fault restart saves the original prefixed
instruction PC and preserves completed elements, pointers and remaining CX.
Asynchronous interrupts remain a separate required completion gate.

## Verification gates

Extend the external oracle to aggregate repeated executions at the same actual
source PC until the next executed instruction, checking final state and every
data/I/O transaction. Do not model REP results by copying the RTL algorithm.
Keep single-element cases, both DF directions, both widths, all segment
overrides, pointer wrap, overlap, zero/one/large counts and comparison early
termination. Check exact post-instruction PC and execute its successor. Add
element-boundary/reset properties, repeat non-vacuity witnesses and directed
zero-count/no-access and partial-progress boundary tests. Re-run original
historical software, lint, formal, simulation and synthesis before sign-off.

## Oracle preparation evidence

The pinned Unicorn engine executes REP with one code callback per element and
may expose a final zero-count callback at the same PC before advancing. The
generator now aggregates those callbacks through actual advancement to the
successor; single-instruction cases retain their previous behavior.

An INS probe also reports an extra zero-valued destination-memory write before
the input callback, then the real input-value write. Unicorn's pinned
[gen_ins source](https://github.com/unicorn-engine/unicorn/blob/2.1.4/qemu/target/i386/translate.c#L1326)
explicitly performs this dummy store to detect a page fault before consuming
input. The generator validates each complete probe/input/final-store triple
(addresses, values, space and direction), then excludes only the dummy probe.
Its fixture has ordinary RAM and port callbacks that cannot observe RAM during
input, so the probe has no remaining architectural effect. Unexpected callback
patterns fail generation. This is an externally sourced normalization, not an
extra RTL zero write. CMPS callback read order likewise supplies an abstract
functional sequence, not native timing. Native I/O/fault ordering still needs
separate evidence before full-chip sign-off.

ASSUMPTION A6: functional CMPS reads the destination before the source, matching
the pinned oracle. This establishes neither native cycle order nor exception
priority. Independent string programs validate data/flag/pointer effects;
historical string software and native ordering remain sign-off gates.
