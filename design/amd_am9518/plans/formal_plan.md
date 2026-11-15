# Formal Proof Boundary — AMD Am9518

SymbiYosys (sby) with one `.sby` file using tasks `bmc`, `prove`, `cover`.

DES itself is not formally provable at 64-bit/16-round scale with the
available solvers; the algorithm's correctness is established by the
independent-oracle KAT suites in `plans/testplan.md` instead. Formal
verification covers the bus/control contract and datapath bookkeeping:

## Properties (formal/amd_am9518_formal.sv, `ifdef FORMAL)

Interface protocol:
- P1: The tri-state enable for MP0-7 asserts only when (latched MCS low) ∧
  (MR/W high) ∧ (MDS low) ∧ (selected register readable) — never drives on
  a write cycle or when MCS is high.
- P2: MAS·MDS both low (two consecutive synchronized samples) triggers the
  hardware reset state; during the following five clocks command writes are
  ignored (A11).
- P3: A rising MAS edge in Multiplexed Control Mode latches MP2/MP1 and the
  current MCS level; between MAS edges the latch is stable.
- P4: Status bit S0/S1 (MFLG/SFLG) equal the Figure 6 association of the
  current M4/M3M2 applied to (input not full)/(output not empty) and the
  active-session condition for input flags — for all eight mode/flag
  combinations, proven exhaustively via a free `anyconst` mode register.
- P5: PAR status bit equals odd-parity check of the most recent
  parity-checked byte (one-hot byte counter relation).
- P6: Command Pending set/clear lifecycle: set on any Load/Read command,
  clear exactly after the eighth transferred byte (plus internal cipher
  completion for encrypted loads), never set by Start/Stop/Reset.
- P7: FIFO safety: input register never accepts a 9th byte in ECB/CBC (no
  overflow corruption); output register never pops past empty (read-enable
  gated).
- P8: The DES engine starts only when the input register holds a complete
  block (8 bytes; 1 byte in CFB) and an active session exists.

Reachability covers:
- C1: each command class decoded and completed (key load, IV load/read,
  encrypted load, start, stop, reset, encrypt-with-M-key).
- C2: each cipher mode (ECB/CBC/CFB) and both directions complete a block.
- C3: parity error and latched-parity states observed.
- C4: hardware reset via MAS·MDS observed and recovered.
- C5: output flag active with data flowing on both master and slave ports
  (dual-port row of Figure 6).

## Tasks

- `bmc`  — depth 40: covers the five-clock blackout, full key-load
  transfers and single-block sessions with slack.
- `prove` — k-induction for the invariant set (P1, P3-P7 induction-friendly;
  P2/P8 bounded-checked in bmc as well).
- `cover` — C1-C5 non-vacuity check (mandatory per repo convention).

Solver: default (boolector/yices as available in the toolchain container).
The properties wrap `amd_am9518_top` with free command streams; the
constraint set models legal strobe timing (strobe width ≥ 1 synchronized
sample, MAS high separation before MDS activity as the host contract
requires).
