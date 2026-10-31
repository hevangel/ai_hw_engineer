# Protected ordinary CS descriptor transaction

This engine connects [ordinary CS validation](code_load_check.md) to the
functional byte bus. The core integrates it for protected direct far JMP and
commits CS/IP/cache only after successful completion. Protected CALL/RET,
system-descriptor resolution and architectural exception delivery remain
outside the integrated slice; the engine does not enable PE by itself.

Sources: Intel 210498-005 Appendix B JMP/CALL check order and the pinned
[86Box descriptor-read/accessed helpers](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86seg.c#L85).
The helper supplies independent evidence for consuming all eight descriptor
bytes and always writing the A byte on the 286, even when already set. The
primary logical checks before CS commit define the validation decision.

An idle start snapshots selector, target offset, CPL, CALL/JMP, caller's
complete old-stack capacity decision, selected GDT/LDT base/limit and LDT
validity. Busy starts and changes to any request input are ignored. Null and
table faults complete before any descriptor traffic. Otherwise consume eight
ascending byte reads. Retain bytes 0..5 for the checker and preserve bytes 6/7
as a separate 16-bit tail; perform the entire checker decision after all eight
handshakes. Ordinary descriptor decisions do not consume the tail.

ASSUMPTION A13: the functional CS engine validates the complete ordinary-code
candidate, including CALL stack/target faults, before issuing one accessed-byte
write at descriptor+5. Faults and deferred system descriptors issue no write.
Successful ordinary candidates always write original access OR 01, then publish
the result after the accepted write. A11's byte order and modulo-24 addressing
also apply. This contract does not establish native CS accessed-update timing,
fault-side-effect ordering, width/LOCK or aliasing. The external emulator's
load-CS helper is not a cycle trace, and its A-write placement must not be used
to infer those native facts. Historical protected transfers and native fault
traces remain required before sign-off.

A special descriptor completes with `special_o=1`, no ordinary code-cache
candidate, its six raw descriptor bytes, and the separate descriptor tail for
the mandatory gate/TSS resolver. This includes unrecognized system types:
classification is not acceptance and does not substitute for the resolver's
legal-type, privilege or presence checks. Protected far JMP uses the tail to
classify task gates and available TSS descriptors without fetching the same
descriptor again. Faults publish the checker's exact vector/error. Only a
successful ordinary load publishes normalized CS selector, base, limit and raw
access byte.

Every completion also publishes the original requested selector and offset as
request context, distinct from valid architectural candidate metadata. Context,
candidate metadata, special raw descriptor and status retain the previous
completed packet throughout a new request, reads and stalled write. Consumers
act only on `done_o`, not a retained `cache_valid_o` while busy. `done_o` pulses
once; the following idle cycle can accept a new start.

Reset suppresses requests immediately and synchronously clears state/results.
It cancels pending work at any cut without undoing accepted writes or emitting
a stale completion. The bus has no external-error response; bus-fault restart,
native interface and architectural delivery remain integration gates.

Verification uses the primary type/check-order reference plus exact byte
transactions. Cover success, pre-read fault, each post-read fault, special
classification, already-set A, hostile live inputs, every reset cut, old
packet retention and a stalled write. Require strict lint, BMC/prove/cover,
compiled mutations and synthesis. CPU/historical protected execution remains
required in addition to this standalone engine.
