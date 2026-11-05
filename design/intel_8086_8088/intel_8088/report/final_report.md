# Intel 8088 final report

## What was built

`design/intel_8086_8088/intel_8088` implements the Intel 8088 (introduced June 1, 1979) as a standalone chip member: `intel_8088_biu` (the four-byte byte-fetch bus interface unit with the 8088's native digital pins) and `intel_8088_chip` (the shared 8086 execution unit from `../../intel_8086/src/` plus the BIU). The execution-unit RTL is referenced by path and not duplicated; its specification, encoding ledger and verification evidence are owned by the [8086 member](../../intel_8086/report/final_report.md).

8088-specific behavior implemented and verified:

- Four-byte prefetch queue, refilled one byte per cycle whenever at least one byte is free (the documented 8088 rule; the 8086 waits for two free bytes).
- Byte-only bus cycles: every 16-bit EU transaction is two ascending byte cycles completing as one transfer; odd words arrive as two lane transactions guarded by the EU's ownership inhibit.
- Pin 34 = SS0 (minimum-mode S0 mirror), no BHE; IO/M polarity reversed relative to the 8086; A8–A15 non-multiplexed and valid for the whole cycle.
- Two-cycle INTA sequence preserved (the EU's whole-word dummy acknowledge is not split); READY waits, halt status, QS encoding, LOCK, HOLD/HLDA and RQ/GT0/1 arbitration as in the 8086 member, with the word-transfer atomicity guard (assumption A6).

## Verification results

All commands ran from the repository root inside the `ai-hw-engineer` tool image (Verilator 5.052, SBY 0.69, Yosys 0.69, xezim 0.11.3, UVM 1800.2-2017). Exact command: `sh design/intel_8086_8088/intel_8088/scripts/run_all.sh`, whose steps were also run individually during development.

| Gate | Command | Result |
|---|---|---|
| Strict lint | `verilator --lint-only -Wall --top-module intel_8088_chip` over the explicit 8088+EU source list | PASS, no warnings |
| Formal | `sby -f` `formal/intel_8088_biu.sby` tasks bmc (depth 32), prove (abc pdr), cover (depth 40) | PASS on all three tasks; every cover reached (wait states, full queue, pop-during-fill, ownership hold/release, both RQ/GT grants, redirect-during-fetch discard, word second cycle, SS0 read/write decode, I/O cycle) |
| Simulation | `scripts/run_sim.sh` (xezim UVM, chip pins) | **TEST PASSED: 11 UVM 8088 control/boundary scenarios; 0 failures**; UVM_ERROR/FATAL counts 0; coverage gate fully reached (waits, writes, code fetches, I/O completes, full queue, QS flush, HLDA, fault, reset) |
| Original software | `scripts/run_software.sh` | `PASS: Intel 1979 figure 2-63 startup through the native minimum/maximum-mode 8088 byte bus, exact instruction boundaries` (two PASS lines); `PASS: unchanged Microsoft MS-DOS 1.25 DEBUG.COM, 22100 RTL instructions, 1239 external DOS calls; register/edit/disassemble/single-step/quit` (two PASS lines, one per bus mode) |
| Directed native tests | `scripts/run_native.sh` | `PASS: 27 native minimum/maximum-mode byte-bus, prefetch, arbitration and reset scenarios` — per-cycle pin invariants (ALE, direction, RD/WR/DEN/INTA, IO/M polarity, SS0 mirror, A8–A15 stability, status-active window, HLDA float, four-byte queue bound) hold in both modes |
| Independent oracle | `scripts/run_native.sh` after `scripts/prepare_vectors.py` | **`PASS: 5740 physical-chip vectors, exact state/memory/next instruction` in minimum mode and again in maximum mode**; vectors pinned to SingleStepTests/8088 tree `aea84484abc79d09639d855b7b0ab32bc9e4dbeb`, captured on a physical AMD D8088 (NMOS, 1982) in maximum mode with no wait states |
| Oracle negative controls | `scripts/check_oracle.py` | `PASS: oracle negative controls reject incorrect next IP and extra writes` |
| Synthesis | `scripts/run_synth.sh` (Yosys generic structural, `check -assert`) | PASS for `intel_8088_biu` (1388 cells: 165 flip-flops, 1218 LUTs, 0 problems) and `intel_8088_chip` (glue over the EU and BIU submodules); not a timing claim |

Every architectural comparison in the vector run asserts exact post-instruction registers (with the oracle's undefined-flag masks), exact memory contents, the ordered byte-write sequence against the physical bus trace and the exact next executed instruction (`next_nop`), satisfying the exact-PC rule for instruction tests.

### Vector selection bounds

The corpus provides 10,000 tests per opcode, far beyond a practical regression. Selection is deterministic: the first 20 accepted tests per pinned corpus file → **5740 vectors**. Exclusions counted during preparation: 350267 tests with upstream non-normal encodings (metadata status outside `{normal, fpu}`, including prefix-only and undocumented classes) and 22 undocumented segment-register field forms. No vector was excluded for queue length. The runner seeds each test with its captured initial queue (at most four bytes, matching the 8088) and serves code fetches beyond the instruction as 90h per the corpus convention. Port reads return FFh, the captured harness value.

## Corrections and findings during development

- The EU's first interrupt-acknowledge transaction is a whole-word request; splitting it would produce three physical INTA cycles. The BIU keeps every INTA transaction a single bus cycle because the physical 8088 INTA sequence is exactly two cycles; the directed test counts exactly two acknowledgements.
- The BIU extends the 8086 member's odd-word ownership guard to every aligned word's two byte cycles (assumption A6); a directed test verifies no grant lands between them.
- SS0 is modeled as the active-low mirror of logical status bit 0, active through the extended wait exactly like the S2:S0 status bus (assumption A7); the scoreboard and directed bench pin this decode in both modes.

## Limits

- No claim of exhaustive silicon equivalence: finite vector subsets, bounded formal depth and directed scenarios only.
- No instruction-cycle-count, prefetch-timing or electrical claim: EU overlap, queue-refill latency (including the physical two-cycle resume after a full-queue read) and arbitration timing are not modeled; the contracts are state, queue contents and bus transactions.
- Analog behavior, package timing, the 4.77 MHz PC environment and DRAM refresh interactions are out of scope.
- `fault_o` is a diagnostic for undefined encodings, not an 8088 architectural exception.
- The vector corpus was captured in maximum mode; minimum-mode vector runs exercise the same architecture through the minimum pin set with the runner's own wait-state patterns.

## Reproduction

```sh
sh design/intel_8086_8088/intel_8088/scripts/run_all.sh
```

First-run downloads land in ignored `work/` (pinned, integrity-checked): the SingleStepTests/8088 corpus tree and Microsoft MS-DOS 1.25 DEBUG.COM (SHA-256 `217b59ff…`). See [tb/software/README.md](../tb/software/README.md) for the software regressions and [the specification](../spec/spec.md) for the assumption ledger.
