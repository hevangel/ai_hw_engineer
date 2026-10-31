# Formal Verification Plan: intel_4001

## Overview

Formal strategy for `src/intel_4001.sv`, run with SymbiYosys from
`formal/intel_4001.sby` (tasks `bmc`, `prove`, `cover`). Properties live in
`formal/intel_4001_props.sv` (safety) and `formal/intel_4001_cover.sv`
(coverage), mirroring the structure of the verified 4004's formal setup.
All assertions are immediate assertions inside clocked blocks (Yosys rejects
concurrent SVA).

## In Scope (Formal)

- ROM read-data integrity: selected address to driven nibbles, for an
  arbitrary (anyconst) address and fully free (anyconst) mask contents.
- Drive-enable gating: the chip drives the bus only in the phases and
  selections the spec allows; never at A1/A2/A3/M-omitted phases, never
  when unselected.
- Address latch protocol: A1/A2/A3 nibble assembly under CM-ROM.
- I/O select semantics: SRC X2 capture, X3 ignored, overwrite, reset clear.
- Port latch semantics: WRR capture at end of X3 when selected, no capture
  when unselected, `clr_n` clears, `rst_n` does not.
- RDR value: `(IO_DIR & latch) | (~IO_DIR & port_i)` driven at X2/X3.
- Reset dominance: `rst_n` low produces the documented next-state for every
  register except the port latch; `clr_n` clears only the port latch.

## Out of Scope (Formal)

- Multi-chip bus arbitration (single instance; simulation covers a
  two-chip shared bus).
- Electrical timing, the dynamic ROM array, pin inversion options.
- Full-system CPU interplay (simulation drives real 8-phase cycles).

## Assumptions (environment = a well-formed 4004-style bus master)

| ID | Assumption | Rationale |
|----|------------|-----------|
| A1 | `!rst_n` in the initial state | Standard reset protocol |
| A2 | `sync == (phase == A1)` while out of reset | The CPU pulses SYNC at A1; keeps the free counter aligned |
| A3 | `cm_rom == (phase <= A3) or (X2/X3 and snooped WRR/WPM/RDR)` | Documented CM-ROM behavior of the 4004 for fetch and ROM-port periods |
| A4 | Port input `port_i` free | Real peripheral values are arbitrary |

`rst_n` and `clr_n` are otherwise free: a reset or clear may arrive in any
period, and the properties check the response (A3's `cm_rom` operand reads
the reset state, so assumptions hold trivially in reset).

## Safety Properties (assert)

| ID | Property | Priority |
|----|----------|----------|
| S1 | `data_oe` implies M1/M2 with fetch-selected, or X2/X3 with snooped RDR and `io_selected` | P1 |
| S2 | When driving M1: `data_o == ROM_FLAT[8*FA +: 8][7:4]` where FA (anyconst) is the latched address and the A3 nibble equals `CHIP_NO` | P1 |
| S3 | Same for M2 low nibble | P1 |
| S4 | `addr_q` equals the nibbles assumed at A1/A2 (anyconst A1/A2 values) whenever CM-ROM qualified them | P1 |
| S5 | `fetch_sel_q` == (anyconst A3 nibble == `CHIP_NO`) after any A3 | P1 |
| S6 | `io_sel_q` == anyconst SRC X2 value after an SRC X2 edge; unchanged by X3 data, unchanged by non-SRC instructions | P1 |
| S7 | WRR with `io_selected`: `port_q` == anyconst WRR data after the X3 edge; WRR unselected leaves `port_q` unchanged | P1 |
| S8 | RDR driving: `data_o == (IO_DIR & port_q) | (~IO_DIR & port_i)` at X2/X3 | P1 |
| S9 | `rst_n` low at an edge: next state has phase A1, `data_oe` 0, `fetch_sel_q` 0, `io_sel_q` 0, `addr_q` 0 — but `port_q` unchanged | P1 |
| S10 | `clr_n` low at an edge: next `port_q` == 0, all other state unchanged | P1 |
| S11 | Phase counter: after any edge, phase = expected next from {sync, X3} rule | P2 |
| S12 | No drive while `!cm_rom_seen` at M1/M2 (inhibited output) | P2 |
| S13 | `port_o` always equals `port_q`; `port_oe` always equals `IO_DIR` | P3 |

## Liveness / Reachability (cover)

`formal/intel_4001_cover.sv` is selected by the `FORMAL_COVER` define and a
goal register latches each named event; the cover task requires every goal
reachable within the depth. The 38 goals enumerate: every instruction-cycle
period (8); selected M1 drives at corner addresses 0x00, 0x01, 0x80, 0xFE,
0xFF (5) and M1/M2 nibble corner values on the bus (2); unselected A3
followed by a quiet M1 (1); the SRC select moving between `CHIP_NO` and
other chip numbers in both directions (2); WRR latching 0x0 and nonzero
(2) and overwriting with a changed value (1); RDR driving 0x0 and nonzero
(2), before any SRC (1), after a WRR returning the written value (1), and
split into its X2 and X3 windows (2); an unselected WRR holding a nonzero
latch (1) and an unselected RDR staying quiet (1); WPM snooped with no
response (1); `clr_n` clearing after WRR (1); `rst_n` asserted mid-cycle
re-entering A1 with outputs inhibited (1); re-lock on `sync` observed at
X3 (1); consecutive fetches of different addresses (1); SRC X3 data
differing from the X2 selection and ignored (1); an A1 nibble ignored when
CM-ROM is absent (1); SRC selecting a chip number other than `CHIP_NO`
(1); and a selected drive across both fetch nibbles (1). Goals are sticky,
so each is discharged by any trace exhibiting the event; all are reachable
by construction, and the cover task passing proves non-vacuity of A1-A4
and S1-S13.

## Proof Strategy

| Task | Engine | Mode | Depth |
|------|--------|------|-------|
| bmc | abc bmc3 | bmc | 24 |
| prove | abc pdr | prove | — (unbounded) |
| cover | smtbmc --unroll z3 | cover | 240 |

BMC depth 24 spans three full instruction cycles, enough for
reset → address latch → fetch → SRC → WRR/RDR → overwrite chains. Prove
runs unbounded PDR; the design's state is small (≈30 flip-flops plus the
free mask/address constants, which PDR treats as immutable). The `anyconst`
address + free mask make S2/S3 hold for every mask pattern and address, not
a sample.
