# Am2914 verification report

Reproduce in `ai-hw-engineer:latest` from repository root:

```sh
sh design/amd_am2914/scripts/run_all.sh
```

Verilator 5.052, Yosys 0.69, SymbiYosys, Z3 and ABC:

- RTL and full multi-chip fixture `-Wall`: PASS without waivers.
- BMC depth 16, unbounded ABC PDR and cover: PASS. All 21 statements reached,
  including all sixteen operations, retained pulses, IE-disabled IRQ,
  overflow/disable, group advance and deferred clearing of a different vector.
  Native inputs obey setup/hold across CP transitions; inputs are otherwise
  arbitrary, with no reset or restricted instruction assumptions.
- **1,441,792 native cases / 6,468,620 native cycles**. Exhaust all 256 request
  patterns with all 256 masks at all 8 thresholds; mask transformations over
  all mask/data pairs; five clear operations across all request/data pairs;
  all 16 instructions, both IE states and GE/GAR/ID/LB combinations; 131,072
  random sequences with sub-cycle input changes in both CP phases.
- **4,608 actual manufacturer interrupt procedures**, Figure 4/PDF177:
  save mask/status, read vector, clear held request after peripheral release,
  service under changed mask/status, then restore original state. Additional
  assertions distinguish bypassed pulses, software IRQ inhibition from vector
  eligibility, and sticky SV across an ineligible vector read/status reload.
- **4,103 original cascade application cases**, Figures 6/9/10/PDF178/181/182:
  eight actual Am2914s and two actual Am2913s, original bidirectional ripple/
  group-advance connections. All 4,096 threshold/vector pairs, simultaneous
  lower requests, exact six-bit vector/status, unique bus driver selection,
  vector 7 boundary transfers, highest-vector disabling/restoration and seven
  nested boundary arrivals pass.
- **255,632,075 total pin checks**, zero failures.
- Yosys synth/check: PASS, **278 cells / 26 flip-flop bits / 16 latch bits**.
  Eight latches model physical pulse catchers; eight model LOW-phase timing
  capture. Nine expected latch-inference warnings (eight scalar pulse
  processes and one eight-bit capture process) and the ABC combinational-
  network advisory remain visible. Zero check problems.

The golden model interprets the manufacturer semantic CSV, authored before
RTL, using generic action fields and a separate priority calculation. Formal
uses a primary encoder truth case and the same independently transcribed
actions. This checks agreement with the selected manufacturer contract; it
does not claim an independently measured silicon oracle. Original application
tests assert exact expected full vectors/status and restoration without the
native oracle, validating every source interpretation in the assumption ledger.

A random-test fixture error initially toggled CP HIGH during a purported
no-edge observation. The testbench now explicitly rejects unmodeled rising
edges and changes high-phase inputs only while CP is already HIGH. This was
caught by the design's own pre-commit verification, and did not require an RTL
semantic change.

Source interpretation is material: native functional paragraphs define the
group update where the scanned DET notation is ambiguous, and explicit
original/1987 SV prose defines sticky overflow. These decisions are marked
ASSUMPTION in RTL/spec and validated through original cascade/interrupt
procedures. Electrical timing, pulse widths, metastability and transistor-level
clear races are outside the settled digital contract. No unresolved functional
issues remain within that contract.
