# Am2918 verification report

Reproduce inside `ai-hw-engineer:latest` from repository root:

```sh
sh design/amd_am2918/scripts/run_all.sh
```

Verilator 5.052, Yosys 0.69, SymbiYosys, Z3 and ABC:

- Unsuppressed RTL/test-fixture `-Wall`: PASS, no waivers.
- Formal BMC depth8 and unbounded ABC PDR: PASS; all four covers reached.
  Capture while Y is disabled/enabled, falling-edge hold and asynchronous OE
  changes are covered. No reset or startup assumptions; D respects setup/hold
  when CP transitions but otherwise remains arbitrary.
- **512 native transitions**: all16 initial words, all16 input words and both
  OE levels. Actual native clocks initialize state; steady-phase D changes,
  falling edges and OE toggles assert unchanged storage and continuous Q.
- **262,144 original MPR-188 bidirectional cases**: all256 initial two-register
  states, all four output-control combinations and all256 new external bus
  values. Both actual chips capture resolved bus values at the edge; continuous
  Q and every pre-/post-edge bus value are checked. One internal driver owns
  each bus; the external source is released when that driver is enabled.
- **65,536 original MPR-189 serial word/stream cases / 1,048,584 clocks**:
  all256 initial words crossed with all256 eight-bit streams, actual Q-to-D
  wiring, asynchronous OE and HIGH-phase serial changes. Eight actual initial
  clocks establish known state; no power-on-zero assumption.
- **15,608,323 checks**, zero failures.
- Yosys synth/check: PASS, **five cells: four native positive-edge flip-flops
  and one inverter**. No latches and zero check problems.

The simple primary truth table pins rising capture, all other holds and
non-inverted outputs. The application scoreboard uses independent bus
resolution and integer shifting, without reading RTL. All source data and
circuits were visually checked in the original scans before implementation.
Analog timing, electrical fanout and contention are outside the settled
digital specification. No known issues remain within that contract.
