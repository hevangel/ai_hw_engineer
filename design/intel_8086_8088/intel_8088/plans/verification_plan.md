# Intel 8088 verification plan

## Layers and ownership

| Layer | Evidence | Owner |
|---|---|---|
| Shared execution unit (architectural) | 8086 member's formal (ALU/EU), UVM transaction scenarios, physical P80C86A-2 vector corpus and DEBUG.COM evidence, inherited by source identity | [intel_8086 member](../../intel_8086/plans/verification_plan.md) |
| 8088 BIU protocol | `formal/intel_8088_biu.sby` bmc/prove/cover over inline assertions: queue bounds, request stability under waits, ownership float, redirect-during-fetch discard, word-transfer atomicity, SS0/IO-M decode covers | this member |
| Native pins, byte bus and queue | `scripts/run_native.sh` directed minimum/maximum-mode scenarios (wrap, queue fill to four, SMC/jump flush, INTA pair and entry, LOCK, word and odd-word arbitration, late requests, reset priority and abort) plus per-cycle pin invariants in the bench | this member |
| Simulation environment | `scripts/run_sim.sh` UVM chip-pin suite: 11 scenarios with exact-IP boundaries, per-cycle scoreboard (ALE, direction, RD/WR/DEN/INTA, IO/M polarity, SS0 mirror, A8–A15 stability, status-active window, HLDA float, four-byte queue bound) and a coverage gate | this member |
| Original software | `scripts/run_software.sh`: Intel 1979 figure 2-63 startup through the chip with exact instruction boundaries in both bus modes; unchanged Microsoft MS-DOS 1.25 DEBUG.COM (pinned SHA-256) with trap single stepping in both bus modes | this member |
| Independent oracle | `scripts/prepare_vectors.py` + `scripts/run_native.sh`: pinned SingleStepTests/8088 physical AMD D8088 corpus, bounded deterministic selection, compared for exact registers (masked undefined flags), memory, ordered bus writes and the exact next executed instruction; `scripts/check_oracle.py` negative controls must reject a mutated IP and missing writes | this member |
| Synthesis | `scripts/run_synth.sh`: Yosys generic structural synthesis of `intel_8088_biu` and `intel_8088_chip` with `check -assert`; no timing claim | this member |
| Lint | Verilator `--lint-only -Wall` over the explicit 8088+EU source list | this member |

## Non-vacuity and qualification

- The BIU formal cover task must reach: wait states, a full queue, pop-during-fill, ownership hold and release, both RQ/GT grants, redirect during a prefetch with a later discard, a completed word's second cycle, SS0 active in a read and a write, and an I/O cycle.
- The UVM coverage gate requires every scenario class and control observation: wait states, writes, code fetches, I/O completes, full queue, QS flush, HLDA, fault, reset.
- Native directed tests assert the exact post-instruction PC and next-executed instruction everywhere; the vector runner's `next_nop` does the same per physical vector.
- The physical corpus bounds: 5740 vectors (first 20 accepted per pinned file), maximum-mode capture, no wait states in the traces, port reads fixed at FFh. Exclusions are counted in `work/vector_selection.json` and summarized in the report.

## Exit criteria

All gates green in the tool image in one `scripts/run_all.sh` pass; the report records exact commands, evidence, accepted counts, exclusions and every qualification in the assumption ledger.
