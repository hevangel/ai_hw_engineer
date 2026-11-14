# AMD Am29338 32-bit byte queue

**First documented: advance information in the 1988 Am29C300/29300 Data
Book.** The Am29338 is an intelligent FIFO: four 32 × 9 RAM slices form a
128-byte ring with stored byte parity. Up to four bytes queue per QCLK
edge and up to sixteen dequeue per DQCLK edge (the larger counts serve
the horizontally cascaded four-chip configuration, up to sixteen bytes
dequeued per cycle). The input word is byte-reordered through the BSW
pins and disassembled LSB-first; the output window presents the four
bytes following the dequeue pointer with their parity. Byte-count
outputs (CNT, FULL, A-FULL, EMPTY, A-EMPTY) support synchronous
flow control; RXMIT rewinds the dequeue pointer for block retransmission;
POS programs each chip's quadrant in cascaded systems.

The reconstruction implements the byte-stream contract with per-byte
parity travel through the rotator, the count architecture (queue count
minus dequeue count), status generation, and the documented control
semantics — with RXMIT sampled at DQCLK edges per the spec ledger.

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Manufacturer provenance](references/README.md)
- [Verification results](report/final_report.md)

Run from the repository toolchain:

```sh
sh design/amd_am29xxx/members/am29338/scripts/run_all.sh
```

The suite runs lint, formal BMC/PDR/cover, a 12,122-drive lockstep
oracle (directed flows, fill/drain/retransmit, random full-space drives),
then synthesis. Electrical timing and the purely asynchronous RXMIT
assertion timing are outside the contract (ledger).

## Roadmap ownership

Chip member: [ai_hw_engineer#174](https://github.com/hevangel/ai_hw_engineer/issues/174);
series card [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
