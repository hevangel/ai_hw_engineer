# Processor-extension data channel connected (2026-11-04)

The core now moves 80287 operand words. Before this change a memory ESC sent
only its command words, and in protected mode it stopped the core
(`fault_code_o=3`).

## Change

- New core ports: `pereq_i` (active-high PEREQ) and `peack_n_o` (active-low
  PEACK#). Both are routed through `intel_80286_native_cpu`.
- A memory ESC arms the channel with the latched operand segment base, limit
  and offset.
- The direction comes from the 80287 opcode map, per the 1985 iAPX 286 PRM,
  App. A, "the CPU will determine the operand starting address and read/write
  status of the instruction".
- Each accepted PEREQ moves one word, following 210760-002 chapter 6:
  - A load reads memory, then writes port FAh.
  - A store reads FAh, then writes memory.
  - PEACK# is low on the word's first operation.
- A word outside the segment raises interrupt 9 and disarms the channel
  (9.6.3).
- Requests are also served while the CPU is halted (App. A). Those transfers
  are not marked as halt cycles.
- While a request is pending, WAIT stops offering its BUSY-stall boundary to
  the event controller. This was found by k-induction: otherwise an INTR
  acknowledge could be started and then stranded behind the transfer.
- A protected-mode memory ESC whose first word is outside a usable segment
  raises #GP(0), or #SS(0) for an SS operand, before its command phase.
  Protected memory ESCs no longer stop the core.

New assumptions are A32 (service points and the first-word check) and A33
(the saved IP for interrupt 9). They are recorded in
`spec/processor_extension_channel.md` and `spec/spec.md`.

## Verification

- `Vintel_80286 --pedc` passes 14 runs, each in both READY modes, using a
  small 80287 stand-in:
  - FLD qword load.
  - FSTP tbyte store at an odd address.
  - Transfers while halted.
  - Interrupt 9 for a word past FFFFh, with no access to the overrunning word.
  - A protected-mode DS operand loaded through its descriptor base.
  - #GP(0) for a null DS and #SS(0) for an SS operand past its limit.
- `run_sim.sh`: 227 PASS, exit 0.
- Connected-core k-induction is in progress; see the PR for the final run.

The standalone `intel_80286_pedc` engine is unchanged and still separately
verified. The core channel reuses its own memory engine, so the byte and
native beat interfaces are both covered. No physical 80287 trace has been
checked.
