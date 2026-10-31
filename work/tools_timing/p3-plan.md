## P3 plan: 4116 access, hold and write-window semantics

P3 is the last open item from this review, and the one that keeps memory delays
`idealized` in `board/timing.json`. It is a model change, not a harness change,
so it needs its own PR and a board-level re-timing pass. Plan below, based on
what P1 and P2 already measured.

### 1. Model (`design/apple_ii_chips/src/a2_4116.sv`)

Add three parameters, all defaulting to `0` so the checked-in behaviour stays
bit-identical and every existing regression keeps its meaning:

| Parameter | Meaning |
|---|---|
| `T_RAC` | RAS falling edge to valid data |
| `T_CAC` | CAS falling edge to valid data |
| `T_OFF` | CAS rising edge to data invalid (output hold) |

Output window: data becomes valid at `max(ras_fall + T_RAC, cas_fall + T_CAC)`
and stays driven until `cas_rise + T_OFF` (or RAS rise, whichever comes first).
Today the model drives on `!CAS & read_cycle`, i.e. `T_CAC = T_OFF = 0`.

Write window: sample `DI` at the later of CAS fall and WE fall during CAS, and
flag a violation when DI is not stable for `tDS` before and `tDH` after that
edge. Today the model samples only at the edge.

Implementation note: the file already declares itself a non-synthesizable event
model, so timestamped `always` blocks are in keeping with it; the guarded
`generate` branch keeps `T_RAC = T_CAC = T_OFF = 0` on the current continuous
assignment path.

### 2. Unit test

`design/apple_ii_chips/tb/tb_4116_timing.sv`: drive RAS/CAS/address, measure
when D0 becomes valid and when it releases, against the three parameters.
Two runs matter: all-zero must reproduce the current behaviour exactly, and a
datasheet set must show the expected access and hold offsets. A negative control
(hold asserted too early) must fail.

### 3. Board-level fallout, which is the real work

P1 measured the read data arriving at +469 ns (typical) and +472 ns (maximum)
with the DRAM held at its idealized 20 ns. A real 4116 access time is
150–250 ns depending on grade, and the report already predicts the failure mode:
the video data latch captures Hi-Z between CAS cycles today precisely because
the model has no output hold. Expect the same run to fail differently once
`T_RAC`/`T_CAC`/`T_OFF` are real, and expect the CAS/latch chain to need work.

So step 3 is: enable the characterized 4116 entry in `board/timing.json`
(remove `idealized`), re-run `scripts/run_timing_sim.sh`, and only then decide
whether the latch timing or the model is wrong. Do not weaken the socket or
frame comparisons to make it pass.

### What would unblock it

* 4116 speed grade actually fitted on the revision-0 boards (and therefore
  `tRAC`/`tCAC` at that grade) — the schematic does not state it.
* Confirmation of whether the early-write path or the read-modify-write path is
  the one the board exercises for CPU writes, since that decides which edge
  `tDS`/`tDH` must be checked against.
