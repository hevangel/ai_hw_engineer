# 8086 review: prefetch in interrupt entry, NMI at reset, shadows in REP — 2026-11-21

## What broke and how it was found

An external code review of `design/intel_8086_8088/intel_8086` at
`dfdc0db` ([ai_hw_engineer#286](https://github.com/hevangel/ai_hw_engineer/issues/286))
reproduced three defects with a probe harness driving the native pins. The
design's own suite had passed all three, including all 566,721 physical-chip
vectors:

1. **Prefetch during interrupt entry** (finding 2). The spec promises CODE
   prefetch is suspended across acknowledge and entry. When the queue had
   room, up to three fetches of the abandoned code stream were interleaved
   with the vector reads.
2. **NMI high at reset** (finding 3). An NMI line already high when reset
   released was taken as a rising edge, so a type-2 interrupt ran before the
   reset vector's first instruction with SS:SP still 0000:0000.
3. **Interrupt shadows inside a REP string** (finding 8). `STI; REP MOVSB`
   took INTR after its first element, and `MOV SS,AX; REP MOVSB` took an NMI
   after its first element, although the spec says both shadows last through
   the following instruction.

The same execution unit runs inside `intel_8088_chip`, so all three applied
to the 8088 as well.

## Root cause and why verification missed it

- **Prefetch.** `prefetch_suspend_o` was a range compare over the state enum
  (`INT_START..IRQ_VECTOR`). Interrupt entry also passes through the shared
  `BUS` and memory states, which lie outside that range, and the BIU
  prefetched in those clocks. The native check only forbade a CODE cycle
  between the two INTA cycles, and every directed interrupt test took the
  interrupt with a full queue, where no prefetch could start.
- **NMI at reset.** Reset forced `nmi_previous` to 0 instead of tracking the
  pin. No test held NMI high through reset. The 80286 core already tracked
  the pin through reset; the 8086 core had not been compared with it.
- **Shadows.** `BOUNDARY` cleared `mask_shadow` and `all_shadow` as it began
  fetching the following instruction. The REP element check and the WAIT poll
  still tested those flags, so they were always 0 there and could never block
  anything. The shadow tests only checked the boundary straight after the
  shadow-setting instruction. Single-instruction physical vectors cannot see
  a multi-element string being interrupted. The review's own first pass also
  called the shadows sound before a second pass traced the flags.

All three escaped for one reason: each rule was tested only in its easiest
state (full queue, NMI low at reset, a one-step following instruction). No
test drove the state in which the implementation's shortcut stops holding.

## Fix and re-verification

- Prefetch: a registered `interrupt_entry` flag is set where entry starts and
  cleared in `INT_DONE`, independent of enum order.
- NMI: reset loads `nmi_previous` from `nmi_i`.
- Shadows: `BOUNDARY` copies the live flags into per-instruction bits, and
  the REP check tests those (assumption A7). WAIT stays exempt so a busy
  coprocessor cannot defer interrupts indefinitely (assumption A8).

Each fix has a directed test that fails on the previous source. The fixes are
in the `design/intel-8086-review-fixes` branch, alongside the review's other
findings (undocumented encodings, LOCK release, the HALT indication, the
iterative divider, the NMI accept race and the latched INTR decision). Run
`design/intel_8086_8088/intel_8086/scripts/run_all.sh` and
`design/intel_8086_8088/intel_8088/scripts/run_all.sh` to re-verify. Results
are in the 8086 final report.

## Prevention

- A directed interrupt test drives entry from a partly empty queue: right
  after a taken jump, in both bus modes. It checks that no CODE cycle occurs
  from the first INTA or vector read until the handler's first fetch.
- Every edge-detected input gets a test with the line held active through
  reset.
- A rule that lasts "through the following instruction" is tested with a
  following instruction that takes more than one step: a REP string, WAIT
  and HLT.
- A status signal derived from a state-enum range is a review smell: use a
  registered flag set and cleared at named states.
