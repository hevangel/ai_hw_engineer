# Sampled CIA integration results

The assembled `mos_6526` connects all sixteen registers to the verified
timer, TOD, serial and sampled interrupt blocks. Pins are sampled on PHI2
rising edges; registers and peripheral pipelines advance on falling edges.
See the [specification](../spec/spec.md) for the source/profile ledger.

## Measured simulation

On Verilator 5.052 and xezim 0.11.0, `scripts/run_sim.sh` passes the same
**1,109,946 checks over 351,165 PHI2 cycles per simulator**:

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

These integration expectations are directed specification checks written
for this design. They are not an unchanged whole-CIA independent oracle.
The external VICE timer comparison remains a separate stronger timer gate.
Its new pre-boundary underflow output also matches the external oracle on
all 3,623,621 cycles; the registered interface is unchanged.

The sampled interrupt foundation separately passes every one of 1,024
mask/source combinations and acknowledgment/pending-enable races:
7,175 checks in each simulator. Strict lint, BMC/PDR and all five reachable
covers pass; synthesis produces 58 generic cells.

## Formal and synthesis

Whole-device BMC at depth 32 and unbounded PDR safety proofs pass with
multiclock modeling. Properties include reset, register-write preservation,
resolved port reads, pin enables, handshake and every child block's
assertions. All **34 covers** (seven integration covers plus child covers)
are reachable; the last is reached at step 41 of the depth-64 cover run.
Yosys 0.69 synthesis and `check` pass with **1,668 generic cells** including
both timer instances and all other child blocks. Strict `-Wall` lint passes.

## Required before compatibility sign-off

The selected sampled interrupt profile is not a completed physical old-CIA
revision. Timer-B/read-ICR loss, precise IRQ/read races, physical CNT/SP
synchronizer latency, TOD reset disagreements and cascade/subcycle timing
remain explicit external-validation gates. Independent historical CIA
software and complete-device captures/reference traces are required. The
four requested systems remain pending; this report does not claim C64
compatibility or a completed console.
