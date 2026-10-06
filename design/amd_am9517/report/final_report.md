# Am9517 observed validation report

The complete `scripts/run_all.sh` flow passed in `ai-hw-engineer:latest`
on October 3, 2026. This is a synthesizable functional reconstruction of the
original AMD controller under the [specified contract](../spec/spec.md).
Original physical timing and undocumented silicon behavior are not established
by these tests.

| Check | Observed result |
|---|---|
| RTL lint | Verilator 5.052, unsuppressed `--lint-only -Wall`, pass |
| Formal | BMC depth 32, unbounded ABC PDR, Z3 cover depth 36; all three tasks and eleven covers pass |
| Native simulation | Verilator and xezim independently pass the same seed-1 suite: 350,971 checks and 66,892 transfers per run |
| UVM | 144 DMA transfers, 216 register-read comparisons; all four channels crossed with three legal transfer types covered; zero errors/fatals |
| Original AMD software | 152 STUP/SDMA cases, 8,320 independent exact-PC instruction comparisons, 1,288 DMA transfers, 608 register reads, 1,656 writes, 95,989 checks |
| Actual two-controller cascade | 32 cases, 1,008 transfers, 11,240 checks across seven usable channels |
| Code coverage | Statements 153/154 (99.35%), branches 112/117 (95.73%), tool-reported toggles 256/256 (100%) |
| Yosys 0.69 synthesis/check | Pass; 2,321 generic cells including 320 flip-flop bits, no inferred latches |

Repeated execution of the native suite for coverage is not counted as additional
independent cases. Generic cell counts are not physical area or timing estimates.
Reproducible scripts retain detailed output under the ignored `work/` directory.

## Evidence and boundaries

Independent original AMD source findings drive active-high asynchronous reset,
grant-time priority selection, CPU programming while HACK is low, disable
inhibition of HREQ, hardware-only status requests, software-only memory-copy
initiation, and the illegal offset-E write. Focused tests exercise each difference
from the project-owned Intel 8237A starting point. Native tests also cover
service/transfer modes, polarities, waits, contention, count boundaries including
65,536 transfers, increment/decrement, automatic reload, copy/fill and both EOP
phases. Reset is asserted between clock edges to check its asynchronous behavior.

The formal harness covers ownership, channel selection, register pointer and
address/count updates, base-register preservation, automatic reload, copy/EOP
sequencing and original AMD control rules. `async2sync` converts reset for the
sampled formal model; simulation checks off-edge reset separately. Formal safety
does not establish original electrical setup/hold or clock-phase timing.

The manufacturer's unmodified [STUP and SDMA object routines](../references/original_firmware.md)
execute on actual Am9080A and Am9517 RTL. A pinned external 8080 emulator checks
every executed instruction, exact next fetch, registers, flags, stack effects and
I/O. The documented AMD ANA/ANI auxiliary-carry adaptation is explicit. Separate
expectations check DMA address, count, strobes and data. Published STUP operand
and object-byte inconsistencies are retained and documented, rather than patched.
Firmware integrity hashes are checked before execution.

The cascade fixture instantiates two actual controllers: the parent's cascade
channel grants the child through DACK/HACK, with native external upper-address
latching, child READY stalls, single bus ownership, terminal counts and unchanged
parent cascade address/count registers checked independently.

## Diagnostics and remaining uncertainty

The UVM run emits 25 library warnings involving xezim UVM component-name
constraints; it reports zero UVM errors and fatals. Yosys emits five expected
array-to-register replacement warnings for asynchronous-reset channel arrays.
RTL lint is clean. Simulation-only native BFMs use localized BLKSEQ,
PROCASSINIT and UNUSEDSIGNAL options; those options are absent from RTL lint.

The uncovered statement is the illegal-FSM recovery default at RTL line 324;
formal legal-state safety rules out reaching it through supported operation.
Five branch alternatives remain uncovered. See the [coverage report](coverage_report.md).

Assumptions A1–A7 remain qualified in the specification and RTL. In particular,
unequal memory-copy source counts/reload use the compatible Intersil 82C37A
clarification; N-minus-one programming and underflow termination use that
compatible convention where AMD prose is ambiguous. Original software and
directed integration exercise the chosen contract, but do not resolve the
remaining original-silicon uncertainty. No undocumented physical result is
inferred from passing tests. No unresolved implementation defect was observed
within this contract.
