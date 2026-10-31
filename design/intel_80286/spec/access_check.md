# Protected cached-segment access validation

The combinational access checker validates a planned contiguous reference
against a previously loaded segment cache. It performs no bus transaction,
cache reload, CPL transition or exception delivery. The core uses it for
instruction fetches and segmented operand requests in the current ring-0
slice. Complete whole-instruction prechecks, privilege changes and protected
exception delivery are still needed for broader execution.

Sources: Intel 210498-005 sections 7.2, 7.4.1/7.4.2, 9.6.6 and 11.2.2;
the manual is linked in the [README](../README.md). Pinned
[86Box do_seg_load](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86seg.c#L278)
independently derives the valid interval as limit+1..FFFF for 286 expand-down
data, and 0..limit otherwise. Its explicit `is386` distinction prevents
importing a 32-bit upper limit or 386 granularity/size bits.

Primary text conflict: 7.4.1 includes a sentence suggesting that an expand-down
limit of FFFF supplies a full stack, contradicting that paragraph's strict
greater-than rule. Section 11.2.2 explicitly says limit FFFF gives zero bytes,
limit 0 gives 65,535 bytes, and only expand-up can cover all 65,536 bytes.
This component follows those explicit 11.2.2 intervals and the pinned external
artifact, rather than the contradictory sentence. It does not claim a separate
published erratum or native trace has been obtained.

Inputs are cache usability, access-byte control bits [4:1] (S/E/C-or-ED/R-or-W),
16-bit limit and start offset, 16-bit last-byte displacement, access kind and
SS fault classification. The accessed bit is excluded from the interface,
since it cannot affect permissions. A last-byte displacement of 0 means one byte; FFFF
means 65,536 bytes. This encoding cannot accidentally request zero bytes.
The caller must suppress zero-count REP accesses before consulting this unit.

Access kinds are 0=read, 1=write, 2=execute, 3=read-modify-write. Require a usable
ordinary code/data cache (S=1). Data is readable; code is readable only with R.
Write/RMW requires writable data and always rejects code, even readable code.
Execution requires code. Descriptor presence, privilege and target-register
legality were checked at cache load; they are not re-read or re-evaluated here.
In particular this unit cannot replace CS/SS-load or CPL-transition validation.

Form the final byte with 17-bit unsigned arithmetic. Normal data and all code
require final<=limit. Expand-down applies only to data types 14..17 hex and
requires start>limit and final<=FFFF. Code's conforming bit must not be treated
as expand-down. A multi-byte access cannot wrap through offset 0000. Permission,
usability or interval failure rejects the planned reference with #SS(0) for SS,
otherwise #GP(0); it never manufactures a late #NP from descriptor memory.
`allow_o` and `fault_o` are complementary decisions. The caller gates an actual
event/transaction, so an idle combinational fault is not itself CPU delivery.

The parent remains responsible for instruction-level fault priority, stack
allocation/SP arithmetic and wrap rules, complete multi-access prechecks,
rollback/restart and limiting every fetched instruction. A contiguous-range
decision does not establish the legality of a whole PUSHA/ENTER/interrupt or
outer-level return. Real-mode behavior and the native bus remain outside this
component. Verification must use independent interval arithmetic/type lists,
all kinds and boundary spans, BMC/prove/cover, mutations and synthesis.
