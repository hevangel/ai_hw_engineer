# Original AMD Am9517 specification

Specification precedes RTL. Primary sources are the 1979 AMD Designer's Guide
PDF245–260 (datasheet) and PDF297–316 (application brief). This targets the
original Am9517 rather than silently importing the later Am9517A/8237A contract.
The existing Intel 8237A design is a reusable implementation starting point;
the AMD register map, grant-time arbitration and pin/reset behavior are audited
independently against original documentation before reuse.

## Digital interface

Four channels provide current/base 16-bit address and count registers, six-bit
mode, masks, software requests, fixed/rotating priority, demand/single/block/
cascade service, read/write/verify, autoinitialization, increment/decrement,
READY waits, compressed/extended write timing and external/internal EOP.
Channels0/1 support memory copying/filling; source software requests initiate
copies and destination count terminates them. Cascading forwards DACK/HREQ
without driving address or transfer strobes.

The original RESET pin is active HIGH and asynchronous. Other inputs use the
single sampling clock; separated bus data/OE and strobes replace bidirectional
pins. HACK is the original hold-acknowledgment input (named `hlda` at the
functional port). A full 16-bit address and a one-edge `transfer_valid` commit
are conveniences; systems supply native high-byte latches/data routing.
Propagation delays, internal multi-phase clocks and physical setup/hold margins
are outside this digital reconstruction. Verify ignores READY as in the reused
compatible controller model; real transfer paths wait at S3/SW/S4.

## Original AMD programming and arbitration

Address/count offsets0–7 share one global low/high byte pointer. Writes update
base/current simultaneously; reads return current only. Offset8 reads status
and writes command;9 writes software request;A writes one mask bit;B writes a
mode;C clears byte pointer;D reads Temporary/writes Master Clear;F writes all
four mask bits. Original Figure13 at PDF306 explicitly marks **E write illegal**.
Do not import Intel's clear-all-masks command at E. Undefined accesses use the
explicit deterministic adapter below rather than a guessed physical read value.

Command bits: memory-copy enable0, source hold1, master disable2, compressed3,
rotation4, extended-write5, active-low DREQ6, active-high DACK7. The original
application Figure15 reverses the printed source-hold labels, while its adjacent
prose and the datasheet PDF250 explicitly say bit1=1 inhibits source address
change. Follow that consistent prose/datasheet, documenting the diagram error.
Mode bits match channel1:0, type3:2, auto4, decrement5 and service7:6.

Status high bits reflect normalized hardware **DREQ inputs** (PDF306), not the
union with software requests used by the existing Intel implementation. Sticky
low bits record internal/external EOP and clear on read. Software requests are
nonmaskable but require block mode (original datasheet PDF250). In memory-copy
mode source hardware DREQ does not initiate a copy; software channel0 does.

Original PDF307 specifies arbitration as the first action on receipt of HACK.
Resolve the currently eligible highest-priority channel at that grant, allowing
a higher-priority request arriving during the hold wait to win. Original PDF309
allows programming whenever HACK is inactive, including while HREQ is active.
Master disable inhibits HREQ, and programming may change pending eligibility.
The CPU must not program registers while asserting HACK.

## Counts, data movement and reset

Normal transfers update the current address modulo65536 and decrement count.
The compatible count convention is N-1 for N transfers, including FFFF for
65536; original prose says count reaches zero without describing the internal
underflow edge, so this convention remains an explicit assumption validated
by full-range tests and the original setup program. Completion sets status,
clears requests, emits internal EOP and masks non-auto channels; auto channels
reload their base address/count instead. Demand pause retains current values;
single service relinquishes the bus after each byte; block continues after
DREQ falls. No selected transfer may begin before HACK or commit without it.

Memory copy uses two four-clock halves and Temporary data; destination TC
controls termination. Source hold inhibits address advancement, not source count.
The original brief recommends equal source/destination counts but does not
fully specify unequal source-count behavior. Retain the compatible Intersil
82C37A clarification as assumption A3 rather than claiming it is explicit AMD
silicon behavior. External EOP during source is retained until destination
completion; its source reload is phase-qualified (assumption A4).

RESET and Master Clear reset control/status/pointer, mask all channels, clear
Temporary and abort service. Address/count/mode programming is unspecified on
hardware reset; this model initializes it deterministically. Master Clear
preserves channel programming. Original asynchronous RESET immediately clears
control and disables all bus outputs; Master Clear is a synchronous CPU access.

## Assumption ledger

- **A1:** Illegal reads leave data undriven with zero convenience data; illegal
  writes, including E, do nothing. Simultaneous CPU strobes have no effect.
- **A2:** Hardware reset clears otherwise unspecified channel programming;
  Master Clear preserves it. Software must initialize modes before service.
- **A3:** Memory-copy source count/reload follows the compatible Intersil 82C37A
  clarification, not an asserted original AMD detail. Equal/unequal counts and
  phase termination must be tested explicitly.
- **A4:** A source-half EOP finishes the current byte before ownership release;
  source reload remains phase-qualified. Dedicated phase tests pin this adapter.
- **A5:** Count N-1 and underflow completion follow the compatible programming
  convention; original STUP object code is tested exactly, including its literal
  count07 rather than silently changing it to the conflicting printed operand7F.
- **A6:** A request withdrawn/masked/disabled before HACK produces no phantom
  transfer; the controller cancels a now-empty wait and re-resolves valid grants.
- **A7:** READY and most controls are sampled at rising edges instead of the
  physical falling-edge/multi-phase timing. Separate commit signals define the
  functional memory/peripheral boundary and avoid repeated writes under waits.

Inline ASSUMPTION comments and original-software/integration evidence are
required before sign-off. No undocumented behavior is silently inherited.

## Validation evidence for assumptions

A1 is checked by undefined-offset and simultaneous-strobe tests, including E
while a masked hardware request is asserted. A2 is exercised by original STUP's
Master Clear and original SDMA programming/readback, reset-register and off-edge
reset tests. A3/A4 are pinned by equal/unequal source counts, copy/fill, source-
and destination-phase EOP tests; the originals do not resolve the remaining
physical source-count uncertainty. A5 is exercised by both original programs,
including STUP's literal07, and exact one/65536-transfer native sequences.
A6 is checked by late-priority and pending disable/programming scenarios. A7 is
used by original software with the actual CPU HOLD/HACK exchange, READY waits,
and a real two-controller/seven-channel cascade with an external address latch.
Software compatibility validates these functional conventions without claiming
physical-chip measurements of undocumented behavior.
