# Sampled CIA integration results

The assembled `mos_6526` connects all sixteen registers to the verified
timer, TOD, serial and sampled interrupt blocks. Pins are sampled on PHI2
rising edges; registers and peripheral pipelines advance on falling edges.
See the [specification](../spec/spec.md) for the source/profile ledger.

## Measured simulation

On Verilator 5.052 and xezim 0.11.0, `scripts/run_sim.sh` passes the same
**1,110,841 checks over 351,578 PHI2 cycles per simulator**:

- All 65,536 DDR/latch combinations for both ports, resolved input reads
  that differ from output intent, output enables and PRB handshake release.
- Reset/register decoding, stopped timer loads and delayed force-load
  behavior; control force-load reads as zero.
- Timer B external CNT mode, Timer A cascade, CNT-gated cascade with
  enabled and inhibited events, and PHI2 Timer A pulse/interrupt routing.
- All 256 serial input bytes and all 256 serial output bytes through the
  actual sampled CNT/SP pins; Timer A supplies transmit baud pulses.
  Open-drain enables assert only for low drive and release for high bits.
- FLAG falling-edge interrupt, serial completion, TOD alarm and timer
  source routing through ICR; source acknowledgment and delayed D7 clearing.
- Both TOD input dividers, alarm comparison, coherent hour-read snapshots
  and tenths-read release while the live clock continues.
- Selected PHI2-high read enable and PHI2-low bus release.
- Both original Lorenz PB6/PB7 timing tables as direct regressions, with
  GPIO inputs held different from the internal timer read result.

These integration expectations are directed specification checks written
for this design. They are not an unchanged whole-CIA independent oracle.
The external VICE timer comparison remains a separate stronger timer gate.
Its pre-boundary counter/start/underflow read views also match the external
oracle on all 3,623,621 cycles; the registered interface is unchanged.

The sampled interrupt foundation separately passes every one of 1,024
mask/source combinations and acknowledgment/pending-enable races:
9,364 checks per profile in each simulator, including current-cycle
source/D7/IRQ views, adjacent-read loss and recovery. Strict lint and
BMC/PDR pass for both profiles, with nine reachable covers for the
affected profile and six for the unaffected profile. Synthesis checks
both profiles separately: 72 generic IRQ cells affected, 67 unaffected.
See the [Transactor report](transactor_report.md) for their independent
original-software qualification.

## Formal and synthesis

Whole-device BMC at depth 32 and unbounded PDR safety proofs pass with
multiclock modeling. Properties include reset, register-write preservation,
resolved port reads, pin enables, handshake and every child block's
assertions. All **39 covers** (seven integration covers plus child covers)
are reachable; the last is reached at step 47 of the depth-64 cover run.
Yosys 0.69 synthesis and `check` pass with **1,833 generic cells** including
both timer instances and all other child blocks. Strict `-Wall` lint passes.

## Independent historical software

`scripts/run_software.sh` runs unchanged public-domain Lorenz 2.15
`cia1pb6.prg` and `cia1pb7.prg` as maintained in VICE SVN revision 45243.
The fetcher checks SHA-256 for both binaries and all original included
source/provenance files. The binaries and expected tables are not rebuilt
or modified. On the native NMOS CPU and assembled CIA in Verilator:

| Program | CPU clocks | CIA reads | CIA writes | Success store PC | Next instruction PC |
|---|---:|---:|---:|---|---|
| cia1pb6 | 20,566 | 466 | 1,377 | 0843 | 0846 |
| cia1pb7 | 20,409 | 466 | 1,377 | 0843 | 0846 |

The harness asserts exact startup PCs/opcodes and the exact instruction
following the success store, and fails immediately on the original failure
mailbox. Actual RTS instructions implement the documented console/vector/I/O
stubs. Raster reads are fixed in the border and no DMA occurs. This is an
isolated software fixture, not a C64 system.

The original PB6 test found a timer-selected PRB read-phase defect. The
correction and prevention are recorded in its
[escaped-defect note](../../../failure_notes/2026-10-19-mos6526-timer-port-read-phase.md).
The maintained original sources are
[PB6](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/general/Lorenz-2.15/src/cia1pb6.s)
and [PB7](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/general/Lorenz-2.15/src/cia1pb7.s).

The expanded fixture now executes original 901227-03 KERNAL vector/I/O and
interrupt routines with two actual CIA instances. All eleven unchanged
Lorenz CIA programs pass over 41,195,603 clocks, including counter/ICR reads,
cascade, execution from registers and NMI-sensitive CIA2 timers. The
[software report](software_report.md) records every program, exact CPU
checkpoints, firmware/source hashes and environment limits. That extension
exposed further counter/ICR/IRQ cycle-view defects, documented in the
[current-cycle failure note](../../../failure_notes/2026-10-20-mos6526-current-cycle-reads.md).

## Required before compatibility sign-off

The selected sampled interrupt profile is not a completed physical old-CIA
revision. Physical Timer-B/read-ICR loss windows, precise IRQ/read races, CNT/SP
synchronizer latency, TOD reset disagreements and cascade/subcycle timing
remain explicit external-validation gates. Additional independent
IRQ/TOD/serial software and complete-device captures/reference traces
are required. The
four requested systems remain pending; this report does not claim C64
compatibility or a completed console.

Original serial-delay and TOD latch/stop programs also run against both
actual CIAs and the native CPU fixture. The [serial report](serial_software_report.md)
records 21 unchanged hardware timing samples and the completion/read-race
fixes. The [TOD report](tod_software_report.md) records 66 original time
comparisons over 19,629,050 clocks. Both use explicit timing stimuli; neither
claims a complete C64 board or resolves silicon revision capture gates.
