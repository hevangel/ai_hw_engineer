# Native NMOS bus reconstruction (in progress)

The existing `mos_6502.sv` remains the verified functional-bus implementation.
A separate `mos_6502_native.sv` is being developed for the 6507/6510 and
console prerequisites. It must not be substituted into released systems
until the following native gates pass. This document precedes its RTL.

## Target contract

One external transaction per phase-two cycle, including otherwise ignored
reads and old-value RMW writes. A state denotes the transaction currently on
the pins; the positive clock edge completes it. `bus_we=1` writes and zero
reads, `fetch_o` identifies an opcode fetch. Board logic must not treat an
internal execution clock as an extra transaction. RDY stalls read cycles
with pins/state held; writes continue despite RDY low. Interrupt/reset and
SO pin transitions need their own tests in addition to opcode vectors.

Retain all 16 bits of PC/address internally, including when a 6507 wrapper
exposes only A12:A0. 6507 has no IRQ/NMI/SO input pins; BRK and the internal
interrupt/vector machinery still exist. Do not truncate PC to thirteen bits.

The final target includes all documented NMOS instructions and the
undocumented behaviors used by period software; unsupported opcode traps
are an interim development state, not an acceptable completed 6507.
Keep WDC CMOS extensions distinct. NES requires a separate decimal-disabled
mode and Ricoh DMA/APU integration; SNES requires its distinct 65C816 core.

## Required native sequences

- Implied/accumulator: opcode fetch plus discarded read of following PC.
- Immediate: fetch plus operand read, execute on that read's completion.
- Zero page indexed: operand read, discarded unindexed zero-page read,
  then indexed access with eight-bit wrapping.
- Absolute indexed/indirect-Y: form the low-byte sum without carry first;
  expose the wrong-page access before the corrected access when crossing.
  Stores and indexed RMW always perform the indexed dummy read.
- Indexed-indirect: operand fetch, discarded zero-page read, wrapped indexed
  pointer low/high reads, then data access.
- RMW: read data, write the original byte, then write the modified byte.
- Branch: operand read, discarded following-PC read when taken, and the
  wrong-page read when crossing. The next executed PC must match exactly.
- Stack: PHA/PHP include dummy-PC read; PLA/PLP include dummy-PC and current
  stack read. RTS/RTI have their complete documented stack/dummy sequences.
- JSR reads target low, performs the stack dummy read, pushes the return
  high/low bytes, then reads target high. RTS discards a read at the pulled
  address before incrementing it.
- BRK/IRQ/NMI: correct discarded opcode/padding reads, stack bytes/B flag,
  vector addresses, interrupt polling latency and NMI hijacking behavior.
- Reset: two discarded PC reads, three stack reads/decrements with writes
  suppressed, then FFFC/FFFD reads. Warm reset preserves general registers;
  undefined power-on state must not be confused with a guaranteed reset value.

## Evidence and independent oracle

- MOS [January 1976 hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf)
  and [programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf).
- [SingleStepTests 65x02](https://github.com/SingleStepTests/65x02), pinned at
  `2f6980a2d95757486c7bee24355c360e40e2a224`, `6502/v1` for NMOS and the
  separate `nes6502` variant later. Each case supplies independent initial
  and final registers/RAM and an ordered address/value/read-write bus trace.
  These are **emulator-generated reference vectors**, not physical captures;
  the project README explicitly describes its generation methodology.
- Netlist/physical-trace comparisons remain required for timing or unstable
  undocumented behavior where documentation and generated traces disagree.
  Do not modify the external oracle to match this RTL.
- Timing reference: [perfect6502](https://github.com/mist64/perfect6502/tree/09fc542877a84318291aa42dab143a3e2c3db974),
  revision `09fc542877a84318291aa42dab143a3e2c3db974`, using the recovered
  Visual6502 transistor netlist. This is a simulation of a photographed die,
  not a physical logic-analyzer capture. The fetcher verifies seven source
  and license hashes. Simulator code and netlist carry different licenses;
  the netlist header retains CC BY-NC-SA 3.0 attribution to Greg James,
  Brian Silverman and Barry Silverman, with source `www.visual6502.org`.
  They stay in ignored test inputs, separate from synthesizable RTL.

## Die-derived timing regression

`native_netlist_test.cpp` boots the unmodified netlist through instructions
that establish registers, then seeds only the Verilator verification model
at the same SYNC fetch boundary. Production RTL has no test injection port.
Both receive identical pin changes between PHI2 rising edges and the
following falling edges, and independent memories. Compare every bus
address, read/write direction and written byte for 770 scenarios / 69,300
cycles: 64 pin-transition positions, ordinary and page-crossing branches,
RDY, IRQ, NMI, combined RDY/IRQ and RDY/NMI, and NMI across BRK. No trace
values are generated from RTL or patched in the external simulator.

Observed hardware-latch details incorporated into the model:

- RDY holds the sequencer, but the indexed-address carry latch corrects
  the dummy address on the following cycle, even while stalled.
- IRQ inputs and NMI pending edges feed the instruction polling point,
  rather than being admitted directly by the following opcode fetch.
- Same-page taken branches poll on the operand cycle. Cross-page branches
  also poll at their final correction cycle.
- SEI/CLI update the I latch during a held implied cycle. A stalled SEI
  can therefore mask an IRQ that arrived after its opcode fetch.
- The BRK/interrupt T5 latch clear loses an NMI edge that arrives too late
  to change that interrupt's vector. The vector-high cycle is not another
  instruction poll. Later NMI arrivals are serviced after a handler instruction.

This matrix does not establish subcycle setup/hold windows, all RDY effects
on every internal ALU latch, or unstable opcode compatibility across dies.
- Retain Klaus Dormann's real-software regression. Add real Atari software
  with the 6507/TIA integration and exact PC plus next-instruction tests.

## Verification gates

First develop the documented instruction bus sequences against independent
vectors; then add undocumented groups and interrupt/RDY/reset races. Compare
**every** bus transaction and exact final PC/registers/RAM, with no unlisted
memory accesses and no padding to absorb landing errors. Require coverage
of page crossings, stack/zero-page wraps, both branch decisions, RMW writes,
binary/decimal corners and representative RDY stall positions.

Final sign-off also requires formal BMC/prove/reachable covers, clean lint,
synthesis, full authentic software execution and board timing comparisons.
The main chip README/index and final report must identify which engine was
tested and which native requirements remain open.

## Undocumented profile and explicit assumptions

The independent [MAME NMOS operation definitions](https://github.com/mamedev/mame/blob/master/src/devices/cpu/m6502/om6502.lst)
and [arithmetic helpers](https://github.com/mamedev/mame/blob/master/src/devices/cpu/m6502/m6502.cpp)
provide another external implementation for stable combined RMW operations,
ARR and high-byte-masked stores. Its unstable-operation section is explicitly
qualified and differs from the pinned SingleStepTests profile. No emulator
code is copied into RTL; expected vectors remain unmodified.

- ASSUMPTION: ANE/XAA and LXA use `UNSTABLE_MAGIC=EE`, the unique constant
  matching all 10,000 supplied cases for each opcode in the pinned corpus.
  This models a chosen external profile, not all dies, temperatures or
  internal bus charge. Keep the parameter explicit and validate against
  software/independent captures before calling the final chip compatible.
- LAS uses A=X=S=memory AND S, as the pinned cases specify; MAME's unreliable
  section expresses different behavior. Preserve this discrepancy for trace
  validation rather than altering either external reference to agree.
- KIL tests supply a finite prefix of locked bus activity: opcode, next-PC
  read, FFFF, FFFE, FFFE, then continuing FFFF reads. They are not completed
  instructions. Logical PC remains opcode+1 in this profile. Reset recovery
  and actual warm-reset dummy addresses after KIL require explicit tests.
- Undocumented RMW pairs retain both old/new writes. ARR's decimal flags
  derive from the preadjusted rotate; decimal adjustment changes its result
  and carry as the external arithmetic/reference cases specify.
- AHX/TAS/SHX/SHY mask data with the unindexed base high byte plus one;
  on crossing a page that data byte also replaces the write-address high
  byte. RDY interactions with these unstable stores require separate trace
  validation; passing unstalled opcode records does not establish that case.
