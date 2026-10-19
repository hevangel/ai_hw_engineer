# MOS Technology chips and descendant systems

Requested on 2026-10-18: implement the MOS Technology chips in the supplied
history one at a time, then Atari 2600, Commodore 64, Nintendo NES and Super
Nintendo, in that order. This ledger persists the work between sessions.
The initial inventory below enumerates the named parts; it does not claim that those
parts comprise MOS's entire commercial catalog. This inventory is not a scope limit. Additional catalog parts
and all additional support chips discovered in the machine schematics must be researched and added to the queue.

## Completion gate

Finish a sourced specification, implementation plan, synthesizable RTL,
self-checking tests, formal assertions and reachable covers, strict lint,
synthesis, historical README/index entry and actual-results report for each
chip. State approximation boundaries explicitly. Processor changes also
require independent oracles, exact PC checks and historical software under
AGENTS.md. Do not count scaffolding or a functional CPU as cycle accurate.

## Sequential chip queue

| Order | Part | Purpose | State |
|---:|---|---|---|
| 0 | MOS 6502 | Existing CPU shared by the family | Existing documented-ISA functional implementation; native NMOS bus timing and undocumented opcodes remain system prerequisites |
| 1 | MOS 6532 RIOT | RAM, ports, timer; Atari prerequisite | Digital contract verified: lint, BMC/PDR/five covers, Verilator/xezim and synthesis; silicon/software integration pending ([report](../design/mos_6532/report/final_report.md)) |
| 2 | MOS 6522 VIA | Ports, timers, serial shift register | Sampled digital implementation verified: all registers/modes, lint, BMC/PDR/ten covers, both simulators and synthesis. NMOS timing/source discrepancies remain open ([report](../design/mos_6522/report/final_report.md)) |
| 3 | MOS 6530 RRIOT | Mask ROM, RAM, ports, timer | Both KIM-1 mask variants verified: ROM hashes, full 8 KB map, BMC/PDR/six covers, both simulators, original monitor boot/display and synthesis. Physical pin/timing gates remain ([report](../design/mos_6530/report/final_report.md)) |
| 4 | MOS 6507 | Reduced-address/pin CPU | Queued; shares corrected cycle-timed 6502 core |
| 5 | MOS 6510 | CPU with integrated port | Queued |
| 6 | MOS 6526 CIA | Ports, timers, serial, time of day | Queued |
| 7 | MOS 6560/6561 VIC | VIC-20 video and sound | Queued; NTSC/PAL separately tested |
| 8 | MOS 6567/6569 VIC-II | C64 video and memory arbitration | Queued; NTSC/PAL separately tested |
| 9 | MOS 6581 SID | Three-voice sound synthesizer | Queued; digital core followed by explicitly qualified sampled analog model |
| 10 | MOS 8580 SID | Revised sound chip | Queued; revision-specific filter/DAC behavior |
| 11 | MOS 7360 TED | Video, audio and memory control | Queued |
| 12 | MOS 8563 VDC | 80-column video | Queued |
| 13 | MOS 8520 CIA | Amiga peripheral controller | Queued |
| 14 | Agnus, Denise, Paula | MOS/CSG-manufactured Amiga custom chips mentioned in the history | Queued; select original chipset revisions and source specifications individually |

The SID's analog circuitry cannot be signed off as transistor/electrical
equivalent merely because a digital simulation produces sound. Keep digital
verification, sampled audio comparison and any circuit-level validation
separate in its report.

## Systems, after the chip queue

| Order | System | Further prerequisites | State |
|---:|---|---|---|
| 1 | Atari 2600 | Native 6507 bus timing, 6532, Atari TIA, cartridge mapping, controllers, raster/audio | Queued |
| 2 | Commodore 64 | 6510, two 6526s, VIC-II, SID, PLA/memory arbitration, ROMs, keyboard and storage | Queued |
| 3 | Nintendo NES | Ricoh 2A03/2A07 CPU/APU and DMA, 2C02/2C07 PPU, cartridge mappers and controllers | Queued |
| 4 | Super Nintendo | 65C816-derived Ricoh 5A22, DMA/HDMA, 5C77/5C78 PPU, SPC700/DSP, memory/controller interfaces | Queued |

Nintendo's custom parts and Atari's TIA are separate prerequisite designs,
not MOS-branded chips. Research them before implementing their systems.
Every system needs authentic, legally obtainable software regressions,
independent timing/output comparisons and a usable web front panel with
waveforms, following [system conventions](../system/README.md). Do not
create empty system folders or advertise working consoles before those gates.

## Current work

The RIOT implementation covers the manufacturer register map, phase-two bus,
128-byte RAM, port A/B readback distinction, four timer rates, and independent
timer/PA7 interrupt acknowledgment. See its report for measured status and
remaining compatibility limits. The VIA sampled contract also passes its complete flow; its discrepancy ledger remains an open fidelity requirement. The 6530-002/003 implementation now passes its chip and original-monitor regressions. Next: native cycle-timed NMOS 6502 engine and 6507, retaining every unresolved chip/system gate. The full user objective was reaffirmed on 2026-10-18 and remains active; no chip approximation or queued system counts as the completed end state.
