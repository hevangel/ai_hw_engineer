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
| 0 | MOS 6502 | Existing CPU shared by the family | Functional plus native NMOS engine; all 256 slots pass 2.56 million external cases, transistor timing matrix, formal and historical software; full silicon/board timing remains open |
| 1 | MOS 6532 RIOT | RAM, ports, timer; Atari prerequisite | Digital contract verified: lint, BMC/PDR/five covers, Verilator/xezim and synthesis; silicon/software integration pending ([report](../design/mos_6532/report/final_report.md)) |
| 2 | MOS 6522 VIA | Ports, timers, serial shift register | Sampled digital implementation verified: all registers/modes, lint, BMC/PDR/ten covers, both simulators and synthesis. NMOS timing/source discrepancies remain open ([report](../design/mos_6522/report/final_report.md)) |
| 3 | MOS 6530 RRIOT | Mask ROM, RAM, ports, timer | Both KIM-1 mask variants verified: ROM hashes, full 8 KB map, BMC/PDR/six covers, both simulators, original monitor boot/display and synthesis. Physical pin/timing gates remain ([report](../design/mos_6530/report/final_report.md)) |
| 4 | MOS 6507 | Reduced-address/pin CPU | Sampled package verified: exact address/PC checks, original KIM firmware in both simulators, BMC/PDR/12 covers, synthesis; Atari/clock/revision gates open |
| 5 | MOS 6510 | CPU with integrated port | Sampled contract verified: 4,194,304 port combinations, actual CPU RMW/AEC checks, original KIM software in both simulators, formal and synthesis; reset/charge/physical C64 gates remain |
| 6 | MOS 6526 CIA | Ports, timers, serial, time of day | In progress: isolated timer passes 3,623,621 unchanged external-oracle cycles, 86,993 four-state records, formal/six covers and synthesis; assembled CIA passes 1,135,596 checks in each simulator, BMC/PDR/41 reachable covers and synthesis; eleven unchanged Lorenz programs pass with original KERNAL over 41,195,603 clocks; affected/unaffected Transactor loss profiles also pass with an independent CIA and transistor CPU oracle; original serial-delay software matches 21 hardware timing samples, SDR-load logs ten FCEB results and all 65,536 pre-underflow byte pairs survive and two original TOD programs check 66 samples over 19,629,050 clocks; physical/revision qualification remains |
| 7 | MOS 6560/6561 VIC | VIC-20 video and sound | Shared CPU register block verified: 3,557,430 checks in each simulator, strict lint, BMC/PDR/five covers and synthesis; raster/fetch/pixels/audio/input capture remain open ([report](../design/mos_6560/report/final_report.md)) |
| 8 | MOS 6567/6569 VIC-II | C64 video and memory arbitration | Queued; NTSC/PAL separately tested |
| 9 | MOS 6581 SID | Three-voice sound synthesizer | Queued; digital core followed by explicitly qualified sampled analog model |
| 10 | MOS 8580 SID | Revised sound chip | Queued; revision-specific filter/DAC behavior |
| 11 | MOS 7360 TED | Video, audio and memory control | Queued |
| 12 | MOS 8563 VDC | 80-column video | Queued |
| 13 | MOS 8520 CIA | Amiga peripheral controller | Queued |
| 14 | Agnus, Denise, Paula | MOS/CSG-manufactured Amiga custom chips mentioned in the history | Queued; select original chipset revisions and source specifications individually |

Additional catalog discovery: the manufacturer VIC datasheet names the MOS 6512 processor. Its package/clock contract and first-introduced-year evidence are queued; the existing native 6502 does not establish them. See the [VIC source review](mos_vic_source_review.md).

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
remaining compatibility limits. The VIA sampled contract also passes its complete flow; its discrepancy ledger remains an open fidelity requirement. The 6530-002/003 implementation now passes its chip and original-monitor regressions. The native 6502 now passes its measured instruction, transistor-timing, formal and historical-software gates (see native report). The 6507 package now also passes its complete shared-core and package flow, including original KIM firmware. The 6510 sampled port/CPU contract also passes its own formal, simulation, real-software and synthesis gates, with reset/charge discrepancies explicitly retained. Current: 6526 assembled sampled CIA passes its digital integration gates, with an unchanged timer oracle and exhaustive TOD/serial/IRQ checks. Eleven unchanged Lorenz programs now pass with original KERNAL, dual CIAs and exact CPU checkpoints; they found and now regress counter/ICR/IRQ cycle-view defects. Original Transactor software now validates affected/unaffected Timer B loss profiles under an explicit legal RDY phase sweep, with independent CIA and transistor CPU agreement. Original serial-delay software now matches all 21 hardware timing samples and regresses completion/read-boundary defects. Original SDR-load software now also passes ten FCEB measurements after shifter preload/CNT-tail corrections, and latch-zero serial baud qualification follows the independent reference. Original TOD latch and stop/restart programs also pass 66 checked samples over 19,629,050 clocks. Physical revision/capture validation and additional corner-case software remain. Next: implement and independently verify 6560/6561 raster generation, preserving NTSC partial-line/interlace details and every unresolved CIA/chip/system gate. The VIC register component now passes its isolated gates; no full VIC is claimed. The full user objective was reaffirmed on 2026-10-18 and remains active; no chip approximation or queued system counts as the completed end state.
