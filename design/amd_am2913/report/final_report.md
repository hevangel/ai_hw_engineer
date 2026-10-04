# Am2913 verification report

Reproduce in `ai-hw-engineer:latest`, from repository root:

```sh
sh design/amd_am2913/scripts/run_all.sh
```

Verified with Verilator5.052, Yosys0.69, SymbiYosys, Z3 and ABC:

- Unsuppressed RTL/test-fixture `-Wall` lint: PASS, no waivers.
- Formal BMC depth2 and unbounded ABC PDR: PASS. All15 cover statements
  reached: eight priorities, EI-disabled driven zero, enabled/no request,
  and each of the five independent output gate inhibitors.
- **16,384 exhaustive native cases:** all256 request vectors, both EI states
  and all32 gate combinations against the original truth table.
- **4,194,304 actual two-chip cascade cases:** all65,536 request patterns,
  both top EI states and all32 gate combinations. Checks include both local
  vector codes, both EO pins, both gate enables and exact16-input selection.
- **69,700 actual nine-chip hierarchy cases:** empty/all/alternating patterns,
  each of64 individual requests, all4,096 ordered pairs and65,536 seeded
  random full64-bit patterns. All nine encoders are actual RTL instances.
- Total simulation: **27,451,496 checks**, zero failures.
- Yosys synth/check: PASS, **29 combinational cells**, no storage and zero
  check problems. No Yosys warnings; ABC prints its standard informational
  combinational-network advisory.

The independent oracle compiles manufacturer CSV truth rows authored before
RTL. Cascade/hierarchy expected vectors use a separate full-vector search.
No reset, clock or input assumptions are invented. The staleness check accepts
normal Git LF/CRLF checkout differences while checking the generated content.

Electrical propagation and bus contention are outside the settled digital
contract. The nine-chip hierarchy is an additional Am2913 circuit, not the
original eight-Am2914/one-Am2913 application. That application's vector and
status variants now pass together in the [Am2914 regression](../../amd_am2914/report/final_report.md),
using eight controllers and two expanders. No known functional issues remain
in this scope.
