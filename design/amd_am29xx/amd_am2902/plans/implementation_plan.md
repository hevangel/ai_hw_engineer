# Implementation plan

1. Establish physical polarity and the three carry outputs from the rendered
   original sheet before RTL.
2. Implement the expanded group/carry equations with decoded internal P/G.
3. Exhaust all 512 physical pin combinations against a ripple recurrence.
4. Test a 16-bit datapath using actual Am2901 ALUs, then a five-device,
   two-level network covering sixteen groups and 64-bit arithmetic.
5. Prove all combinations, cover generate/propagate/kill/non-Cn group behavior,
   lint both RTL and testbench and synthesize/check. Record sourced history.
