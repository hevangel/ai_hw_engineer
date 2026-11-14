# AMD Am26LS30: dual differential RS-422 / quad single-ended RS-423 line driver

The Am26LS30 is AMD's mode-switched line driver: with MODE high it is
four independent non-inverting single-ended RS-423 drivers; with MODE
low it is two RS-422 differential party-line drivers with complementary
outputs and individual active-low enables (on the pins that become
drivers B and C in RS-423 mode). Outputs do not clamp the line with
power off or in hi-impedance state, and per-output slew-rate control
shapes the RS-423 edges.

First introduced: **1978*** — documented in the
[1978 AMD Schottky and Low-Power Schottky Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1978_AMD_Schottky_and_Low-Power_Schottky_Data_Book_including_Digital_Signal_Processing_Handbook_Second_Edition_197807.pdf)
(PDF pages 310-312) and reprinted in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-30 to 4-35, with the published function table on page 4-34).
No month-level claim is made.

Why it matters here: it is the family member whose package pins change
meaning with an operating mode — the same pin 3 is driver B's data in
RS-423 and pair 1's enable in RS-422 — so the contract is two complete
function tables on one pin map, verified row by row against the
published table. Its mode structure contrasts with the fixed
configurations of the [Am26LS29](../am26ls29/README.md) and
[Am26LS31](../am26ls31/README.md).

This reconstruction implements both documented digital contracts as a
zero-delay combinational block, per the [specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover (both function
tables), exhaustive simulation in Verilator and xezim, and Yosys
synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26ls30/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#196](https://github.com/hevangel/ai_hw_engineer/issues/196);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
