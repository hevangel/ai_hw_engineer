# Implementation and verification plan

1. Visually inspect original Tables1–7 including overbars and shift priority.
   Transcribe register/condition/carry expressions and32 shift rows into CSV.
2. Implement native eight flip-flops and independent combinational output
   multiplexers. Separate shift value/enable signals; no reset.
3. Generate formal and C++ golden functions solely from the prior CSV artifact.
   Prove combinational pins and pre-edge state transitions for arbitrary
   instructions, status, enables and serial pins. Cover all32 shifts, register
   swap, external load, sticky overflow and disabled-enable carry override.
4. Simulate all8192 words over all256 pre-status combinations; exhaust status
   input and per-bit enable axes; exhaust serial inputs and all32 shifts.
   Initialize and observe state via actual Y bus operations, with no debug
   backdoor. Replay manufacturer's interrupt save/two-load restore and
   one-level swap applications, borrow-save and sticky-overflow examples.
5. Run unsuppressed Verilator -Wall, BMC/prove/cover, simulation, Yosys synth
   and check. Record actual counts, historical uncertainty and limitations.
