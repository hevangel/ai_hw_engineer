# Cache-bank reference routing

This combinational frontend selects ES/CS/SS/DS cache state by explicit role,
checks an entire contiguous reference and forms its 24-bit physical address.
It is the connection between the cache bank and the ordinary access checker;
the core memory sequencer must retain role/offset/span before using it. Physical
base aliases cannot identify a role. Descriptor-table and I/O traffic bypass
this segmented-reference frontend through their own checked paths.

The source contracts are Intel 210498-005 sections 7.4, 10.4.2 and 11.2.2,
the [ordinary access contract](access_check.md), and the [cache integration
contract](cache_integration.md). A14 also records the externally sourced retained
CS policy: pinned [MAME's actual instruction fetch](https://github.com/mamedev/mame/blob/fa9419ba91017064d30bc340b266620389f5d1c2/src/devices/cpu/i86/i286.cpp#L1040)
checks the inherited CS limit without requiring its raw reset access byte 93
to describe executable code. Intel permits an intra-segment JMP following PE
entry. Native raw-cache/transition evidence remains an A14 sign-off gate.

Inputs use the core's low-to-high ES/CS/SS/DS packing: four 24-bit bases, four
16-bit limits, four raw 8-bit access bytes and four usability bits. A two-bit
role chooses the reference cache, independently of its base. Offset and last
byte displacement use the existing checker's 16-bit encoding (zero means one
byte, FFFF means 65,536 bytes); kind is read/write/execute/RMW = 0/1/2/3.

Ordinary references use the selected cache's type/permissions, usable flag and
complete normal/expand-down interval. SS classification comes from role 2,
even when another cache has the same physical base. Failures return #SS(0)
for SS and #GP(0) otherwise, with no memory request or architectural delivery.

An explicit `trusted_cs_i` input denotes the retained real-mode CS role, not
a newly loaded protected descriptor. Only a CS execute reference can use that
path. It still requires a usable cache and a complete nonwrapping interval
0..CS.limit. All data references through CS continue to check its raw access
attributes. The flag must never authorize ES/SS/DS or survive a successful
protected CS reload. The core owns that flag's reset/reload/commit lifecycle;
this component cannot validate an incorrect caller lifecycle.

Successful references return (base + offset) modulo 2^24, consistent with the
functional 24-bit address contract. Faults return physical address zero, so an
unchecked speculative address is not exposed as a usable candidate. No bus
transaction is generated here. The caller gates issuance on allow, snapshots
the result before stalls and prechecks whole instructions before any writes.
This unit does not implement SP arithmetic, multi-reference ordering, CPL/load
checks, PE entry, a CS transfer or precise exception delivery.

Verification must independently enumerate permissions and intervals, select
cache roles with unrelated/aliased bases, vary ignored raw access bits and
exercise trusted-CS fetch versus CS data writes/reads. Include physical-address
carry/wrap, every base bit/role, unusable caches, complete-span overflow and
SS fault classification; use unconstrained formal equivalence/covers and
compiled routing/trust/permission/address mutants before core integration.
