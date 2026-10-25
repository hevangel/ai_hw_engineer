# Authored NMOS 6502 specification

Target: all 151 documented NMOS opcodes and all their addressing modes,
decimal ADC/SBC including NMOS flags, stack, reset, IRQ/NMI, RDY, SO,
page-cross and branch dummy accesses, RMW old/new writes, and JMP indirect
page wrapping. Undocumented opcodes deliberately latch fault_o; they are
outside the documented-instruction acceptance contract.

Sources: [MOS programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf),
[MOS hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf),
and independent [SingleStepTests NMOS vectors](https://github.com/SingleStepTests/65x02).
Tests compare every address, read/write direction, written byte, final register,
status and exact next opcode-fetch PC against the externally generated vectors.
No ISS is derived from the RTL. Historical original Apple II Monitor execution
is mandatory in run_all.sh. An independent Klaus functional test adds coverage.

## Interface and cycle contract

One rising clk consumes the current bus transaction and presents the next.
bus_we is high only for writes; fetch_o is high during opcode fetch, including
the discarded fetch at interrupt entry. pc_o/status_o/a_o/x_o/y_o/sp_o expose
architectural state. Synchronous rst_n is the project initialization reset;
res_n is the separate physical warm-reset request. irq_n, nmi_n, so_n and
rdy are sampled on clock edges. RDY holds reads, never writes. NMI falling
edges are retained during RDY stalls. IRQ uses the penultimate-cycle pin sample and pre-update I flag, preserving
CLI/SEI/PLP delay behavior. NMI edge requests pass through the same polling
boundary. A taken same-page branch polls at its operand; a crossing branch
retains that result and also polls at page correction. During a stalled
branch/index correction cycle the address-high latch still corrects. Late
NMI can hijack BRK/IRQ only before the status-push sampling boundary. These
details are checked against the independently recovered transistor netlist
listed in [reference ownership](../tb/REFERENCES.md).
P's bit 5 is always one; bit 4 is a stack encoding, not a stored flag.

## Assumption ledger

- ASSUMPTION: project rst_n chooses canonical startup A/X/Y=0, S=0, P=24.
  Real silicon does not guarantee these power-up register values. Physical
  res_n preserves A/X/Y and decimal state, sets I, and performs three stack
  reads/decrements before the vector reads. The initial stack pointer becomes FD.
- ASSUMPTION: external asynchronous pins meet the sampling clock's setup/hold;
  metastability and sub-cycle electrical timing are not solved in this RTL.
- ASSUMPTION: digital bus inputs are stable before the consuming edge.
  The physical socket adapter samples before phi0 falls and changes pins after
  that edge, allowing the motherboard's real propagation and shared DRAM path.
- Undocumented/unstable NMOS opcodes fault rather than approximating analog
  behavior. No compatibility claim is made for software using those opcodes.

## Completion gates

Require all documented-opcode external vectors, exact bus cycles, exhaustive
decimal arithmetic against an external oracle, interrupt/reset/RDY/SO checks,
Klaus functional software and original Apple II Monitor commands. Run lint,
formal safety/progress with non-vacuity covers, simulation and synthesis.
Tests must check exact next PC; no padding may absorb incorrect PC landings.

## Physical package adapter

`a2_mos6502` maps the original 40 pins, resolves data only while writing,
and consumes a read before phi0 falls. Its startup counter chooses canonical
internal initialization for three clocks; the motherboard RES pin remains a
warm reset. ASSUMPTION: phi1/phi2 outputs are ideal complementary levels;
analog delay and clock non-overlap are not modeled. ASSUMPTION: unresolved
read bits sample high and increment `unknown_read_samples`, matching the
explicit external reference boundary. No electrical validity is inferred.
NC pins 5, 35 and 36 are unused. Only `mos_6502_cycle`, not this resolved-pin
simulation adapter, is covered by the synthesis gate.

## Physical package adapter

`a2_mos6502` maps the original 40 pins, resolves data only while writing,
and consumes a read before phi0 falls. Its startup counter chooses canonical
internal initialization for three clocks; the motherboard RES pin remains a
warm reset. ASSUMPTION: phi1/phi2 outputs are ideal complementary levels;
analog delay and clock non-overlap are not modeled. ASSUMPTION: unresolved
read bits sample high and increment `unknown_read_samples`, matching the
explicit external reference boundary. No electrical validity is inferred.
NC pins 5, 35 and 36 are unused. Only `mos_6502_cycle`, not this resolved-pin
simulation adapter, is covered by the synthesis gate.
