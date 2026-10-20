# MOS 6526 CIA specification and fidelity ledger

## Evidence

- MOS [November 1981 preliminary datasheet](http://www.6502.org/documents/datasheets/mos/mos_6526_cia_preliminary_nov_1981.pdf):
  register map, resolved-pin reads, timer modes, serial buffering, ICR and TOD.
  This establishes existence by 1981, not an exact shipment date.
- [VICE timer implementation](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciatimer.h)
  and [CIA implementation](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciacore.c),
  pinned revision `d928b850b7ef4c1b1826a6efd175d8eaa80344d8`:
  independent software oracle for timer pipelines, TOD quirks and interrupt
  sequencing. Compile unchanged external timer code with test-only service
  adapters; never modify expected values to match RTL.
- [Physical-chip measurements by merlintwa](https://www.forum64.de/index.php?thread/109935-mos6526-cia-detailed-test-vectors-and-models/),
  begun December 2020: separate PHI2 latches, timer/IRQ latency and serial
  input timing. These are reported measurements, not locally reproduced captures.
- [MAME CIA reference](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/machine/mos6526.cpp):
  another independent implementation, including positive TOD input edges.

## Device interface and registers

The complete chip uses PHI2 `clk`, reset, active-low chip select, R/W,
four-bit register address and eight-bit data bus; eight-bit ports with
separate output enables; CNT/SP input and open-drain output intents; FLAG,
TOD and PC handshake; active-low open-drain IRQ intent. Board-level
resolvers provide pullups and external contention, not hidden RTL defaults.

| Address | Register |
|---|---|
| 0/1 | PRA/PRB |
| 2/3 | DDRA/DDRB |
| 4/5 | Timer A low/high |
| 6/7 | Timer B low/high |
| 8/9/A/B | TOD tenths/seconds/minutes/hours |
| C | Buffered serial data |
| D | ICR: pending on read, set/clear interrupt enables on write |
| E/F | CRA/CRB |

Unlike a simple DDR-latch readback port, PRA/PRB reads reflect resolved
physical pin levels for output pins as well as inputs. Timer output can
override DDRB on PB6/PB7. PB access pulses PC low for one cycle; FLAG falling
edges set source 4 regardless of its mask. ICR sources 0–4 are timer A,
timer B, TOD alarm, serial and FLAG. Mask bit 7 selects set versus clear;
read clears pending and releases IRQ with revision-qualified pipeline timing.

## Timer subsystem contract

Sixteen-bit counter and latch per timer, pipeline-qualified start/stop,
force-load, one-shot and continuous operation. Timer A sources PHI2 or
positive CNT edges; timer B sources PHI2, CNT, timer-A underflow or A
underflow qualified by CNT high. Underflow reloads and may stop the timer.
PB output is a one-cycle positive pulse or toggle, set high when started.
Force-load bit reads zero. High-latch writes reload a stopped counter;
latch writes coincident with reload retain the externally established behavior.

The isolated `mos_6526_timer` uses a cycle-completion clock, decoded low/
high/control write strobes, continuous-count enable or external step pulse,
and read-only counter/latch/start/underflow outputs. Each cycle advances the
old timer state before applying the boundary's register write, matching the
external oracle API's documented update-before-write ordering. Underflow,
reload, start/stop and one-shot are checked every cycle, including zero
reloads and writes on underflow. No ideal N+1 timer replaces the pipelines.

## TOD and serial requirements

TOD divides positive 50/60 Hz edges into tenths, selected by CRA7. Registers
are BCD with AM/PM. Hours read latches all four values until tenths is read;
hours write stops counting and tenths write restarts it. CRB7 selects alarm
writes, while reads always return time. Hour rollover and the write-of-12
AM/PM quirk follow independent evidence rather than the preliminary manual's
ambiguous "24-hour (AM/PM)" wording. Alarm compares must include writes and
time changes, with transition/revision behavior separately verified.

Serial receive samples MSB first on qualified CNT events, transfers eight
bits to SDR and raises its source. Serial transmit uses timer-A underflow
to generate half-rate CNT, changes SP on falling CNT, buffers the next byte,
finishes after eight rising edges and returns CNT high. It must preserve
the last SP bit and handle buffered continuation and direction changes.

The isolated serial block accepts already-qualified CNT rising edges and
timer-A baud pulses. ASSUMPTION: direction changes flush active/queued shift
state and release CNT/SP high, while a simultaneous SDR write establishes
the new mode's data/queue. A CPU write on a receive-completion boundary
overrides visible SDR but does not suppress the completed-byte event.
A full single-byte pending buffer is overwritten by a newer CPU write.
These boundary choices require independent physical/revision validation;
the normal documented input, buffered output and MSB-first protocol can be
verified separately without claiming the physical synchronizer is complete.

## Reset and unresolved assumptions

The preliminary sheet resets ports/control/pending/SDR/TOD to zero, timer
latches to FFFF and all port pins to inputs. VICE resets timer counters to
FFFF, stops TOD and uses hour 01 as a common physical value. TOD reset
and invalid-BCD behavior require an explicit revision/profile decision
before their RTL and final sign-off.

The isolated TOD implementation selects `RESET_HOUR=01` and stopped reset,
following the pinned VICE profile; the hour parameter remains configurable.
ASSUMPTION: this reset profile is not established for every physical die.
The BCD digit counters preserve invalid-digit wrap rather than coercing an
invalid software write to a valid time. Writing time hour 12 toggles its
supplied PM bit; alarm-hour writes do not. ASSUMPTION: a simultaneous TOD
tick advances the old clock before a register write overrides its selected
field. An hour read snapshots the pre-boundary time; repeated hour reads
retain that snapshot until a tenths read. Alarm events require changed
clock/alarm data that compares equal, matching the pinned independent code.

- ASSUMPTION: an isolated cycle-level timer models the pinned external
  emulator's pipeline profile; physical subcycle races require captures.
- Resolved port input latches and bus writes occupy distinct PHI2 phases.
  A once-per-clock pin model must not silently claim exact analog timing.
- Old-6526 IRQ delay and timer-B/read-ICR loss differ from later CIA models.
  Select and validate a revision before declaring full compatibility.
- Physical CNT-to-SP sampling can take multiple PHI2 edges; VICE explicitly
  approximates that path. Passing its emulator alone is insufficient there.

## Verification gates

First isolate and verify both timers against unchanged pinned external code
using deterministic and seeded-random per-cycle comparisons. Cover all
16-bit loads, zero/FFFF, stop/start, one-shot/continuous, force load, external
steps and reload/write races. Then integrate the port/ICR/TOD/serial paths
with their own meaningful regressions and reachable formal covers. Require
strict lint, formal BMC/prove/cover, simulation in two tools and synthesis,
plus external CIA software and physical timing evidence before system sign-off.
The timer foundation alone is not a completed CIA or C64 prerequisite.

## Sampled interrupt foundation

The isolated interrupt block uses a legacy-latency sampled profile: new
enabled events schedule IR/D7 and the IRQ pin for the following clock.
Unmasked events still set their pending bits. Enabling an already-pending
source schedules an interrupt; clearing a mask does not cancel a scheduled
or active request. Reading ICR returns pre-boundary flags, releases the
IRQ pin immediately, clears low pending bits on the boundary and clears D7
one boundary later. Fresh source events survive a simultaneous read; a
fresh scheduled request takes precedence over delayed D7 clearing.
ASSUMPTION: these cycle boundaries approximate the old-device pipeline
reported in physical measurements and the pinned VICE reference. This is
not a complete physical old-6526 revision model. The selected Timer B loss
profile is defined below; remaining subcycle/revision races need captures.

## Integrated sampled bus

The chip samples resolved PA/PB/CNT/SP/FLAG/TOD on PHI2 rising edges and
completes bus operations/submodule cycles on falling edges. ASSUMPTION:
reset spans both phases; external pulses shorter than the sample interval
and analog setup/hold windows are outside this sampled interface. Timer A
pre-boundary underflow feeds its ICR source and the edge-qualified serial baud path; its
registered underflow feeds timer-B cascade on the following boundary.
ASSUMPTION: cascade latency follows this selected sampled profile and still
requires complete-device external timing comparison. Timer pulses last a
full cycle; toggle outputs initialize high on a stopped-to-start command.

## Historical software harness contract

Run unchanged public-domain Lorenz 2.15 CIA test PRGs from VICE SVN revision
45243, with SHA-256 pins for binaries and their original source. The harness
uses the native NMOS CPU bus and an actual CIA instance at DC00. Resolved
port inputs loop back driven bits and pull undriven bits high. This isolated
test environment holds VIC raster reads in the border (D011=80, D012=00),
has no DMA, and supplies real RTS instructions for KERNAL console/vector/I/O
entry points. These are explicit environment stubs, not a working C64.
Do not modify CIA assertions or success/failure tables in the PRGs. Enter
through their BASIC SYS address after CPU reset and assert the exact initial
fetch PCs/opcodes. Accept only the original success-mailbox instruction and
its exact following instruction; fail immediately on the failure mailbox.

ASSUMPTION: when PBON selects a timer, the PRB timer-bit read mux uses the
timer's current-cycle underflow/toggle result before its falling-edge output
latch. GPIO bits still read the rising-edge resolved-pin sample. This
distinction is pinned by the original Lorenz `cia1pb6`/`cia1pb7` timing
tables and VICE `ciacore_read(CIA_PRB)`, which updates each timer before
overriding its PRB bit. The preliminary sheet's general resolved-pin read
description does not describe that internal phase exception. Pin-versus-bus
captures remain required; do not use a delayed physical-output loopback as
the internal timer read mux.

### KERNAL-backed timer-test environment

The optional `--kernal` fixture maps hash-pinned original 901227-03 ROM at
E000-FFFF and adds a second actual CIA at DD00, wired to CPU NMI. A six-byte
RAM bootstrap at 0200 executes JSR FF8A (original RESTOR) and JMP to the
unchanged program's BASIC SYS address. Only reset-vector reads select that
bootstrap; IRQ/NMI vectors and all I/O initialization execute original ROM.
PAL flag 02A6 is initialized to one. The console entry FFD2 alone supplies
an explicit RTS read override and records output; original ROM files remain
unchanged. VIC raster inputs remain fixed in the border, no DMA is present,
and processor-port writes do not change the fixture's fixed ROM/I/O mapping.
These are isolated-test environment limits, not C64 system compatibility.

ASSUMPTION: timer counter/control bus reads expose the current-cycle result
before the falling-edge state commit, just as timer-selected PRB reads do.
The isolated timer exports both registered state and a current-cycle read
view. The latter is compared against the unchanged VICE timer's result on
every oracle cycle. Lorenz `cia1ta` test 01 independently requires two
decrements (1E to 1C) rather than the previous boundary's value 1D.

The integrated ICR bus read likewise catches up current sources and the
previously scheduled D7 request before acknowledging the read. The isolated
interrupt block retains its registered-state diagnostic output and exports
a separate pre-acknowledgment cycle read view. ASSUMPTION: source bits are
visible in their event cycle; D7 appears on the following cycle. The
unchanged old-CIA Lorenz tables and VICE ICR catch-up path pin this phase;
physical read-loss windows and IRQ transitions remain separate capture gates.

## Affected Timer B/read-ICR profile

`TIMER_B_READ_LOSS` selects an affected old-device profile (default one),
or an otherwise identical legacy-latency device without this defect (zero).
The latter is not a fast 8521/new-CIA model. The archived Transactor test
reports both affected and unaffected physical chips, so chip numbering alone
does not establish this profile.

The independent VICE `cia_do_update_tb` records a loss marker when Timer B
underflows one cycle after an ICR read. A subsequent clean Timer B event
replaces that marker. On the next ICR read, a marked Timer B pending flag is
removed before returning the value; the marker clears on that read. Other
source bits and D7 are not masked by the marker. The RTL keeps the existing
IRQ request pipeline and applies the read loss to the returned/stored Timer B
flag. A coincident fresh Timer B event uses the previous-cycle read state.
ASSUMPTION: this sampled underflow/read relation applies to Timer B source
events regardless of count mode; the original Transactor detector validates
PHI2 counting, and additional CNT/cascade physical traces remain required.

The permanent regression must execute the original Transactor 104-byte
payload at 3200, validating its own checksum 11949 and exact bootstrap,
payload-return and NMI entry/exit PCs. For a fixed observation window, the
affected profile must print at least one original error star for Timer B and
none for Timer A. The unaffected profile must print none for either timer.
No replacement detector or modified payload may manufacture the stars.

The fixture executes original BASIC 901226-01 WAIT code at B840 with its
documented WAIT 198,7 arguments in 14/15,49/4A and Y=0. It does not run the
whole BASIC parser. A one-cycle RDY read hold every 127 observation clocks,
only while executing B83E-B848, sweeps the missing board/DMA phase. Both
profiles receive the identical legal input pattern; CIA clocks continue.
This is a declared phase-coverage fixture, not a VIC-II DMA implementation.
Without this sweep the simplified environment never exercises the adjacent
ICR-read/underflow window, even with original WAIT code, so zero error stars
alone is not accepted as evidence of an unaffected chip.

The original payload's error-star results are compared with unchanged
`floooh/chips` m6526.h at commit
`9e88298ce56319953ac7a43213a1120359f7a3a6`. That source supplies the tested
timer/interrupt paths; its TODOs for other peripherals make it unsuitable
as a full-device TOD/serial oracle. The recovered transistor CPU also
compares every address/RW/write-data cycle through this software race, with
the same RDY/IRQ/NMI pins and settled bus read data. None of the external
reference code, ROM bytes, DATA payload or original detector is edited.

ASSUMPTION: the integrated logical-cycle IRQ pin uses the caught-up
scheduled request before the CPU's cycle-completion sample, matching the
cycle D7 view. Retaining only the previous committed IRQ state introduces
an extra CPU-observed NMI cycle, visible in Lorenz CIA2 timer tests. This
does not establish subcycle electrical transition timing; that remains an
explicit capture requirement.

## Independent serial delay qualification

Execute the unchanged `CIA/shiftregister/cia-sdr-delay.prg` from VICE SVN
45953, with its original 21-word hardware table and D7FF result store.
The fixture supplies PAL raster bit 7 (312 lines, 63 PHI2 clocks per line),
RAM, reset-vector override and an executing RTS at FFD2 for diagnostic
console output. It supplies no video DMA or screen editor. The program's
raw timer table at 2000, rather than rendered text, determines its result.
Require exact SYS entry 080D, next instruction 080F, and exact result-store
and following instruction PCs; fail on any original nonzero result.

ASSUMPTION: the captured old/new-unspecified C64c/C128D timing table is
represented in this sampled interface by a transmit completion request
four PHI2 clocks after presentation of bit 8
(the fifteenth baud pulse), rather than at the sixteenth pulse. CNT still
rises on pulse 16 to finish the wire transfer. This is a sampled profile:
other divider values and silicon revisions still require captured traces.
The four-cycle request pipeline is flushed on direction change/reset.

ASSUMPTION: a serial completion already visible in the current ICR read is
consumed by that read, instead of being retained for the next read. The
unchanged 21-sample program distinguishes this from the timer/FLAG source
set-wins convention: retaining it produces false early completion in the
following transfer at three polling alignments. Other serial/read races
and the electrical timing of this boundary remain capture requirements.

## Independent TOD software qualification

Execute unchanged SVN 45953 CIA/tod read-latch and write-stop programs,
including their embedded comparison tables, without firmware substitutions.
The explicit PAL fixture supplies 63 clocks per line, 312 lines per frame
and one TOD rising edge per frame (50 Hz nominal). This preserves the
original programs' frame-counted waits. It is a timing stimulus generator,
not VIC-II logic or DMA. Require exact entry JMP at 080D, target SEI at
0820, original D7FF result-store PCs and following self-loop JMPs, and the
original sample counts in zero-page loopcnt. Reset hour remains unchanged:
both programs initialize the TOD explicitly and do not qualify power-up.

## Serial shifter and pre-underflow buffering

The original SVN 45953 cia-sdr-load program and its provenance report that
consecutive SDR writes preserve two bytes without waiting for Timer A.
An idle transmitter must preload the first byte independently of baud;
the next byte occupies the single pending slot. Presenting the final SP
bit frees the shifter for the next byte while that last bit remains on SP
until its CNT rising edge. Do not wait for that edge to accept the next
byte. The original program's ten FCEB console results must pass its own
screen table, and separate pin decoding must prove both bytes survive.

ASSUMPTION: idle preload occurs at the sampled SDR-write boundary. The
pinned VICE model describes a two-clock shifter-load pipeline; source and
physical data must qualify writes immediately adjacent to baud edges
before claiming that subcycle behavior. At the sampled boundary a write
on last-bit presentation queues the next byte without cancelling the
outgoing SP/CNT transition; a genuinely full
pending slot retains the latest write. Direction-switch/write races remain
an explicit sampled convention, not an electrical guarantee.

The pinned MAME serial_output implementation also distinguishes a sustained
Timer-A underflow level from separated pulses: latch zero leaves the level
asserted and produces only the first serial half-bit. Qualify the integrated
baud input on a rising underflow level. A latch-one transfer must still send
all eight bits; a latch-zero transfer must not raise serial completion.
Timer IRQ and cascade counting retain their separate event semantics.
A free-shifter SDR write releases CNT high and resets the serial bit phase,
retaining the prior final SP bit; this matches MAME serial_load/output and
the original ten-result FCEB table. The physical two-clock load pipeline
remains separately qualified rather than inferred from the polling table.
