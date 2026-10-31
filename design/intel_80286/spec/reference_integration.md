# Core reference routing and request context

This integration connects the [cache-bank frontend](cached_reference.md) to
instruction fetch and segmented operand requests. The current ring-0 slice
also routes ordinary protected CS and DS/ES/SS descriptor transactions through
the exclusive descriptor owner. Protected event-gate delivery and IRET remain
incomplete; a protected fault is packetized and stops visibly at code 3 before
the real-mode IVT path.

Every segmented operand request must retain its explicit ES/CS/SS/DS role,
16-bit starting offset, full byte count, read/write intent and permission kind.
The ModR/M preparation stage retains role and offset for a later writeback;
never reconstruct the role from a physical base or recompute the EA after POP
or another register update. The request context is immutable through validation
and every held/accepted byte. A distinct validation state runs the cache-bank
frontend before any bus request. On allow, snapshot the checked physical start
and advance that address only on accepted bytes. On failure, issue no operand
request and preserve the faulting instruction context. Real-mode protection
diagnostics retain their existing stop behavior; protected denial creates the
current fault packet but protected delivery still stops at code 3. Neither
boundary claims complete architectural exception delivery or whole-instruction
restart for every instruction family.

Route ModR/M reads/writebacks, moffs, XLAT, SGDT/SIDT memory images, all ordinary
push/pop/call/return/frame operations, event stack frames, PUSHA/POPA, ENTER/
LEAVE and every string source/destination through this segmented path. A
read-modify-write operand checks write permission before its first read.
Table-register memory operands remain segmented references; actual IDT vector
reads use a separately bounded linear table path. IN/OUT and string I/O use
the separate I/O path, including 16-bit port wrap. INS still prechecks its
destination before an I/O side effect as required by complete instruction
integration; adding per-reference validation alone does not establish all
protected INS/CALL/ENTER/event prechecks.

Instruction fetch uses a separate CS execute frontend for every prefix/opcode/
extension/ModR/M/displacement/immediate byte. Retain existing ten-byte and
offset-wrap instruction checks. The explicit trusted-CS state starts true and
is true on real CS reloads; a successful protected code-load commit clears it.
PE entry retains it. A failed fetch check suppresses bus issuance and
development-stops at the appropriate original PC rather than waiting forever.

Expose functional debug context (segmented flag, role, current byte offset,
original transaction size and permission kind) alongside the existing bus.
Its meaning is qualified by bus_req. Fetch is CS/execute/size 1. Linear table
and I/O requests have segmented=false. This is verification instrumentation,
not native 80286 pins. Assertions and simulation must check address/context
coherence, full-span validation before first traffic, stability through stalls,
no partial architectural changes during validation and cancellation on reset.
Directed cases must distinguish aliased segment roles, stack/default/override
selection, RMW permission intent, segmented table operands versus linear IDT,
and string I/O versus memory. Exact PC/successor and historical/oracle replay
remain mandatory. Prior snapshot proofs do not certify this changed core.
