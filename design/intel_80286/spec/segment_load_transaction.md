# Protected segment-load transaction engine

Status: standalone engine verified and integrated for protected MOV-to-DS/ES/SS.
The core commits the visible selector and hidden cache only after successful
completion. Protected exception delivery remains pending. This engine wraps
[ordinary DS/ES/SS validation](segment_load_check.md) and still reports a
completion packet for its parent to consume.

Sources are Intel 210498-005 6.3/6.6/7.4 and the pinned
[86Box read_descriptor/loadseg_2386/accessed-bit helpers](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86seg.c#L85).
That artifact reads all four descriptor words on its 16-bit bus path, validates
before setting accessed, and completes the accessed update before publishing
the new segment cache. Its 286 path writes the access byte even if A was set;
the conditional skip is for later processors. Native cycles/LOCK remain open.

## Request, bus and completion contract

`start_i` is accepted only while idle and reset is released. Snapshot selector,
CPL, target, selected GDT/LDT base/limit and LDT validity. Ignore request-input
changes and starts while busy. An idle accepted start may coincide with the
previous completion pulse; this begins a separate transaction.

Check null selectors and complete table bounds before issuing a descriptor
read. A null data load completes with an unusable-cache packet and its original
selector, without reads or writes. A null stack/invalid-table/bounds fault
completes with the checker's exact error and no bus traffic.

ASSUMPTION: A11 extends A1's functional bus scheduling. For a nonnull in-range
selector, issue eight ascending byte reads at selected-base + (selector & FFF8).
The 24-bit physical bus adds modulo 2^24. Retain architectural descriptor bytes
0..5; consume but ignore reserved bytes 6/7. Validate only after all eight read
handshakes. A validation fault completes without a write. Successful validation
issues one byte write of original access OR 01 at descriptor address +5,
including when A was already set. Native transaction order/width/LOCK, top-of-
address-space aliasing and actual protected historical software remain required
evidence before full sign-off; the functional byte sequence alone is insufficient.

Hold request, address, direction and write data stable until ready. Read data
is meaningful only on a ready handshake. No completion or new result metadata
is published while an accessed-byte write is stalled. After that write accepts,
publish a one-cycle done pulse and the selector/cache-valid/base/limit/raw-access
result, without a fault. Fault/null packets publish only after their decisions;
metadata payload is zero when unusable. Results remain stable until a later
completion or reset; accepting a new start must not erase the previous result.

Reset immediately suppresses bus requests and synchronously clears state,
completion and result metadata. A reset during any read, validation or accessed
write cancels the transaction. Accepted memory writes remain accepted; there
is no rollback and no phantom completion after reset. This interface has no
external bus-error response; native/fault integration remains a separate gate.

## Verification

Use the independent descriptor type/privilege reference for semantic results
and transaction contracts for ordering/capture/publication. Exercise GDT/LDT,
nulls, all validation fault classes, both A-bit values, arbitrary ignored high
bytes, table/physical boundaries, changing request inputs during stalls,
back-to-back starts and reset at every accepted-byte/validation/write boundary.
Check exact accepted reads and the sole accessed-byte write; check that no
partial cache metadata escapes. Formal BMC/prove/cover must avoid ready/fairness
assumptions and witness success, pre-read fault, post-read fault, held write and
reset during activity. Mutation detection must follow successful compilation.
The core now integrates this engine for ordinary protected MOV-to-DS/ES/SS.
Passing the engine alone does not establish that integration, broader
protected execution or architectural exception delivery.
