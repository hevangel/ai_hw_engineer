# Library formal plan

Manufacturer truth tables are the independent source for the 46 gate/strobe
module checks in `formal/ttl_truth_tables_props.sv`. Constant truth vectors
specify each one-bit gate; all inputs are unconstrained and both output states
have covers. The gate equation RTL is not used to generate those truth vectors.

The counter contract compares 74160/161/162/163 against a transition table and
binary arithmetic model, including reset priority, load, hold, enable, terminal
count and non-vacuity covers. Initial clear is assumed and BCD parallel loads
are restricted to decimal digits. The shift contract checks every 74164 bit
against an independently updated bit-history model after initial clear.

The RAM contract uses an `anyconst` watched address, tracks writes to that
address, and proves inverted readback and drive control. ABC PDR proves the
memory invariant without relying on finite read-after-write distance.

The FIFO contract compares a ring-buffer implementation with a shift-queue
reference. Its ordering/flag assertions use bounded model checking; this is not
an unbounded FIFO ordering proof. Covers independently reach full occupancy
and mixed transactions. The exact checked depths are recorded in the SBY file
and current report. Long simulation exercises multiple ring wraparounds.

Every family check includes a separately executed cover task. These eight
targeted families supplement simulation of the implemented catalog; they do not prove
every part's complete native datasheet. Original 74181 BMC, unbounded proof,
cover, exhaustive simulation and UVM tests remain unchanged.

## Storage, universal drivers and passive switches

The 74574 contract checks registered data and independent drive control. The
universal-driver contract checks opposite latch-enable polarities in fixed
registered and transparent modes. The passive 7416213 switch contract uses an
independently transcribed component-label table for all eight select states,
arbitrary external data/drive masks, contention and validity. Its covers reach
three-way transfer, conflicting drivers and full isolation.

Switch topology case tables are lowered with `memory_map` before SMT solving:
immutable combinational lookup contents must not become arbitrary ROM state in
induction. This changes the verification representation, not the assertions.
Formal results include hashes of the runner, configuration and declared sources;
the report rejects stale or missing family tasks.
