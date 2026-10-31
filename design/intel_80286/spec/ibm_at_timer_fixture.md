# IBM AT timer fixture contract

This is a verification fixture for the IBM 5170 BIOS, not a complete IBM AT
system or an 80286 package feature. IBM's March 1984 technical reference,
[system timers and block diagram, PDF pages 26–28](https://bitsavers.org/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf#page=26),
identifies the 8254-2, clocks all three channels from a nominal 1.190 MHz
oscillator (the diagram shows 2.38 MHz PCLK divided by two), ties gates 0/1
on, routes OUT0 to IRQ0 and OUT1 to the refresh request circuit, and drives
gate 2 from port `61h` bit 0. OUT2 participates in speaker generation. The
reference's rounded frequencies do not establish a precise oscillator ratio.

## Implemented adapter

`tb/intel_80286_at_timer.sv` instantiates the shared
`design/intel_8253_8254` timer with `IS_8254=1`. It decodes the canonical
BIOS ports `40h`–`43h`; other aliases are deliberately unspecified until the
original board's address decoding is established. `io_req_i` denotes an I/O
request. A timer read or write is strobed for a rising `clk` edge only when
the selected request is accepted with `io_ready_i=1`. The timer's read data
is driven combinationally for an accepted read. This matters because its
register and read-phase state advances on each active bus clock edge.

The caller supplies the sampled counter-clock levels separately from bus
acceptance. Gates 0/1 are high; `port61_bit0_i` supplies gate 2. All three
OUT signals are exposed without modeling the refresh latch, PIC, speaker
filter, or port 61 register. The timer's integration reset and sampled-clock
abstraction are described in its own specification; they are not physical
8254 pins or electrical timing claims.

## Remaining integration and evidence

- The separate `intel_80286_at_fixture` now connects the adapter to accepted
  CPU I/O. The standalone adapter test checks stalled transfers and counter
  clock progress during a stalled read. The BIOS test exercises always-ready
  and periodically stalled CPU traffic; timer progress while the CPU is
  halted remains untested.
- Two deterministic virtual clock schedules are exercised. The present CPU
  model's internal simulation ticks are not qualified 6 MHz package cycles,
  so their ratios are fixture assumptions, not native IBM AT timing evidence.
- Captured timer input bytes are replayed into Unicorn for instruction-state
  and data-transaction comparison. The shared RTL timer is not an independent
  oracle for its own behavior. Both BIOS channel-1 bit tests now pass in the
  two virtual-clock scenarios. See the
  [connected BIOS report](../report/2026-10-29-at-timer-bios.md).
- Add the refresh request latch, interrupt controller and other board devices
  as required by later POST; compare the unchanged BIOS against an independent
  machine. No full POST, boot, physical timing or 8254 equivalence is claimed
  by these bounded fixture tests.
