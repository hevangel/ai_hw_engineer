# MC146818 formal plan

`formal/motorola_mc146818.sby` checks the inline `ifdef FORMAL` properties
of `src/motorola_mc146818.sv`. The first cycle is in `rst_n` reset. All
inputs are unconstrained: bus strobes, AD, CE, `tick_i`, RESET and PS. So
are the power-on contents of all 64 locations, because the `$readmemh`
initialization is excluded under FORMAL. Properties are guarded with
`$past(rst_n) && rst_n`.

Proved (abc pdr, unbounded, FAST_SHIFT 0):
- `irq_n_o` equals NOT(PF·PIE + AF·AIE + UF·UIE), and the IRQF bit the
  chip reads back equals the same expression;
- register C bits 7 and 3-0 and register D bits 6-0 hold no data, and
  seconds bit 7 reads 0;
- register C clear-on-read: after a read of C, each flag that read as 1 is
  0 unless its own event fired in that clock;
- each flag rises only through its own event (tap edge, alarm match at the
  update, end of the update cycle);
- VRT rises only through a read of register D with PS high, and is 0 after
  PS is low;
- UIP rises only on the 1 Hz divider edge with SET = 0, and never rises
  while SET stays 1;
- RESET pin low: PIE, AIE, UIE, SQWE and all flags are 0 and IRQ is
  released; SET, DM, 24/12, DSE, DV and RS are unchanged; user RAM is
  unchanged; time bytes are unchanged except by the update itself; the bus
  is not driven;
- writes to C or D do not change VRT;
- time bytes do not change during the update cycle;
- the sequencer uses only its three states, and the period counter never
  exceeds 1040.

Covered (smtbmc yices, FAST_SHIFT 10, depth 40). Each interrupt source is
reached through its own event, not through the power-on image:
- a periodic-flag edge with PIE driving IRQ low;
- an alarm match at an update with AIE driving IRQ low;
- the end of an update cycle with UIE driving IRQ low;
- a register C read clearing UF and releasing IRQ;
- UIP rising on the 1 Hz edge;
- a read of D setting VRT.

Calendar semantics, rates and timing are checked by lockstep simulation
against the reference model, not formally.
