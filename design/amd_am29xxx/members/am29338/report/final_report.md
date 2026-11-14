# Am29338 verification report

Verified digital contract: 128-byte ring FIFO from four 32 × 9 parity
slices — up to four bytes queued per QCLK edge (Table 1) with BSW
byte-reorder and LSB-first disassembly, up to sixteen bytes dequeued per
DQCLK edge (Table 2), output window with stored parity and PYERR,
PDERR on the bytes about to be queued, CNT/FULL/A-FULL/EMPTY/A-EMPTY
status from the queue-minus-dequeue count architecture, POS quadrant
base at RESET/RXMIT.

## Reproducible results

Toolchain ai-hw-engineer:latest: Verilator 5.052, Yosys 0.69,
SymbiYosys/Z3/ABC. Run `sh design/amd_am29xxx/members/am29338/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: clean, no suppressions.
- Simulation: 12,122 lockstep drives (109,125 checks): the Figure 6/7
  queuing/dequeuing examples, BSW sweep across all four reorderings,
  fill-to-full with A-FULL/FULL transitions and drop-on-full, full
  drain, the Figure 5 RXMIT retransmit flow, POS quadrant behavior under
  RESET and RXMIT, simultaneous queue/dequeue at different pointers, and
  12,000 random full-space drives with periodic resets/retransmits.
  Value checks are masked on never-written cells (undefined data);
  status/enable checks always apply. The external oracle is transition
  exact against the RTL's async-reset semantics (RESET applies on the
  1→0 transition, with the reset values re-assigned at clock edges while
  held low).
- Formal: BMC depth 16 (smtbmc z3) PASS, unbounded ABC PDR (prove)
  PASS, cover PASS at depth 40 — status/count contracts, pointer-window
  equality, parity functions, counts-saturate and reset-hold invariants;
  covers for all BQ/BDQ byte counts, BSW encodings, statuses, parity
  errors, RESET/RXMIT and cascade quadrants. (The DUT's two independent
  clocks mean the property layer checks per-timestep contracts; the
  sequential discipline is exercised by the lockstep simulation.)
- Synthesis: Yosys `synth; check -assert` clean.

Bring-up findings recorded as verification-infrastructure lessons: the
driver-vs-oracle check must be symmetric against a single reference
(the C++ mirror and the Python oracle initially diverged from each
other — a two-model diff isolated the case); async control ordering
(RESET/RXMIT take effect before the outputs they gate) must match
between model and RTL; and a q_cnt saturation was lost in one RTL
restructure and caught by the random drives at the 128-byte boundary.

## Limits

RXMIT is modeled as sampled at DQCLK edges (ledger — a single always_ff
cannot carry two independent async controls here); the purely
asynchronous assertion timing is outside the contract. Queuing into a
full queue drops overflow bytes and dequeuing an empty queue floors the
count (ledger — undocumented behaviors, deterministic model choices).
CNT reads 0 when the 128-byte queue is full (seven-bit CNT). Contents
after RESET are invalid. Electrical timing is outside the contract.
Advance-information datasheet; no exact first-shipment date asserted.
