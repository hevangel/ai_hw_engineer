# Original manufacturer host software

`original_host.hex` transcribes the published object-code columns of Figures
7.1 and 7.2 in AMD's May 1981 **Am9511A/Am9512 Floating Point Processor Manual**,
by Steven Cheng, PDF pages 36–39 (printed 33–36). Figure 7.1 DEMAND is at
0000–002f; Figure 7.2 POLL is at 0030–006b. These are the original bytes, not
newly assembled replacements or instruction-isolated tests.

The caller supplies HL=big-endian numerator buffer, DE=big-endian denominator
buffer, BC=result buffer and A=command. The routines push bytes low-to-high,
issue the command at port C1, and store four result bytes high-to-low from
port C0. DEMAND relies on PAUSE to stall its first data read; POLL reads busy
before loading and before retrieval. Both return APU status in A. These
original command/data semantics apply to the original Am9511; the fixture
does not import the later A revision's electrical timing.

The listing's first POLL loop is printed with a `JNZ PLOOP2` label even though
its object-code target is **003e**, the first loop. The regression follows the
unambiguous object bytes and exact branch PCs, without changing them or adding
padding to absorb an incorrect landing.

The test fixture runs the existing Am9080A RTL and this Am9511. Every instruction
retirement and next fetch is checked against the pinned external Superzazu
8080 ISS already documented in the Am9080 design. Actual I/O reads are replayed
to that independent CPU oracle; mathematical APU results are checked separately.

[Pinned manufacturer scan](https://github.com/barberd/coco9511pak/blob/0f272e44db724ed7f0e60730499457be230e4e4f/docs/Am9511A-9512FP_Processor_Manual.pdf).

The regression has 330 original-program cases: both routines, ten arithmetic
commands, limit and zero operands, native PUPI, SDIV -32768/-1 and divide-zero,
and two FADD halfway rounding cases. Project-owned setup is a real caller at
0100; a three-byte reset boot overlay retires an exact JMP 0100 and is then
removed, leaving both published routines unchanged. Every subsequent fetch and
retirement asserts exact instruction bytes and PCs, with no landing padding.
The immutable object transcription is checked against `original_host.sha256`
before every firmware run.
