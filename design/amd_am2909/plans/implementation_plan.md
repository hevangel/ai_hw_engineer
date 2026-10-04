# Implementation plan

1. Source specification and independent Figure 6 state table before RTL.
2. Implement separate register/direct paths, OR/ZERO priority and OE metadata.
3. Implement Y+Cn counter and pre-edge-PC push, with circular four-word stack.
4. Verify every control combination and arithmetic/address value against an
   independently structured top-first stack oracle from the original table.
5. Execute original Figures 7/8 microprograms with three real slices and a
   pipeline microstore; check exact fetched/executed PCs and return addresses.
6. Prove state updates, stack retention and carry/pin properties without reset;
   reach covers, lint, synthesize/check, then document observed results/history.
