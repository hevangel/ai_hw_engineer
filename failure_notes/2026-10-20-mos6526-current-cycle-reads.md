# CIA current-cycle counter, ICR and CPU interrupt visibility

## Independent observations

After adding original Commodore 901227-03 KERNAL I/O initialization to the
unchanged Lorenz fixture, three original software expectations failed:

- `cia1ta`, test 01: initial 1E, before 14/01; counter read was 1D, expected
  1C. This occurred after 5,361 CPU clocks.
- After correcting that phase, test 05: initial 1E, before 05/11; ICR read
  was 00, expected 01. This occurred after 255,857 clocks.
- After correcting ICR catch-up, `cia2ta`, test 09: initial 07/11, before
  14/01; counter read was 0F, expected 10, with ICR 81 in both. This occurred
  after 7,189,489 clocks and depended on actual CPU NMI admission.

The independent expectations are the unchanged public-domain
[CIA1 Timer A source](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/general/Lorenz-2.15/src/cia1ta.s)
and [CIA2 Timer A source](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/general/Lorenz-2.15/src/cia2ta.s).
The pinned external
[VICE timer/read implementation](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciacore.c)
catches up timers and interrupt state to the read's cycle before returning.

## Root cause and escape

The isolated blocks update registered state at cycle completion. The
integrated bus returned that previous committed state to a CPU sampling
on the same boundary. Current-cycle timer count/start and ICR source/D7
catch-up were therefore missing. Similarly, the registered diagnostic IRQ
output reached the native CPU's cycle sample one cycle late; CIA1 SEI hid
that error, while CIA2's unmaskable NMI changed the measured timer value.

The earlier unchanged timer oracle validated state after committing a cycle,
so it did not exercise how the integrated bus read that cycle's result.
The original PB6/PB7 programs covered the timer port mux but not counter/ICR
reads or NMI-sensitive software. Directed tests and formal lacked an
independent whole-device phase expectation. The broader historical software
gate was explicitly open; this is still an escaped sampled-design defect.

## Correction and evidence

The timer now exports current-cycle count/start alongside its registered
diagnostic state. The ICR block exports a pre-acknowledgment source/D7 read
view and a logical-cycle IRQ view including the scheduled request. The
integrated CIA uses these at the CPU boundary. The specification records
the phase assumptions and retains physical IRQ transition timing as an open
capture requirement. The RTL does not claim that a logical-cycle output
proves a particular electrical edge or setup/hold margin.

No external oracle, program or expected table was edited. The unchanged
VICE timer now checks both read views and committed state on all 3,623,621
cycles; four-state replay checks both on 86,993 independent records. Formal
proves that current-cycle read/IRQ projections become the next registered
state when acknowledgment does not intervene. Directed integrated checks
exercise the externally found read and interrupt boundaries in both tools.

All eleven original old-CIA Lorenz programs in the expanded flow pass,
including both NMI-sensitive CIA2 timers and both register-execution
clock-mode programs. See the [measured software report](../design/mos_6526/report/software_report.md).
The complete affected lint/formal/simulation/synthesis gates are rerun;
their final measurements are in the integration report.

## Prevention

`run_all.sh` runs the expanded `run_software.sh`. Hash pins preserve the
programs and original KERNAL identity; exact reset, ROM-entry, program-entry,
success post-PC and next-executed instruction checks prevent tolerant entry
or exit assumptions. The original KERNAL executes actual I/O/vector/IRQ
routines; only the documented console and reset-vector bus overrides remain.
Every new timer/read view must be checked before commit against the unchanged
external timer, and both CIA1 IRQ and CIA2 NMI paths must run real software.
