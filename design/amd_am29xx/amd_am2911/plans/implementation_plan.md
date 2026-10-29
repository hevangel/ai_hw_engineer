# Implementation plan

1. Source the variant's two interface differences and transition table first.
2. Instantiate the verified state engine with explicit shared-D and no-OR wiring;
   expose only the original Am2911 digital pins.
3. Adapt the independently sourced table oracle to load the register from D,
   and check all controls on an actual three-slice Am2911 cascade.
4. Execute original Figures 7/8 exact microprogram traces; test stale held
   register versus live D, return-PC push, repeat, ZERO and OE.
5. Prove variant-constrained state behavior with reachable covers, lint and
   synthesize/check; record actual results and variant-specific history.
