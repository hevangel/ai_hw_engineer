# Intel 8086 verification report

## Outcome and reproducibility

The documented 8086 instruction set and native digital chip interface are implemented. `intel_8086_chip` combines the execution unit, six-byte prefetch queue, minimum/maximum-mode bus, READY waits, interrupts/traps, WAIT/ESC, LOCK and HOLD/RQ/GT ownership. `intel_8086` exposes the execution unit separately for functional integration. This delivery contains the chip and verification environment. The [specification](../spec/spec.md) defines the supported encodings, interfaces and assumptions; the [encoding ledger](encoding_coverage.md) assigns evidence to every documented row.

The complete verification flow first passed on October 11, 2026 and was rebuilt and rerun successfully on October 18, 2026 with `ai-hw-engineer:latest`: Verilator 5.052, Yosys 0.69, xezim 0.11.0, Accellera UVM 1800.2-2017, SymbiYosys with ABC BMC/PDR, Z3 and Yices, GNU binutils and Python 3. From the repository root inside the image:

```sh
sh design/intel_8086/scripts/run_all.sh
```

The aggregate script requires every stage to succeed and checks explicit completion/count markers. Initial downloads are pinned and integrity-checked; subsequent runs use ignored `work/` caches. The committed tests and coverage summaries make the evidence reproducible. Passing this suite establishes the listed architectural and digital protocol checks; it is not an exhaustive proof of all silicon states, original instruction-cycle timing or electrical compatibility.

## Results

| Check | Result |
|---|---|
| Strict Verilator `--lint-only -Wall` | Complete native hierarchy passes with no RTL warnings |
| ALU BMC / unbounded prove / cover | All pass; three reached cover goals |
| CPU BMC / unbounded prove / cover | All pass; BMC depth 24, seven reached cover goals |
| BIU BMC / unbounded prove / cover | All pass; BMC depth 32, eight reached cover goals |
| xezim / UVM | Eight boundary/control scenarios; zero errors/fatals |
| Physical-chip corpus, direct EU | 566,721 instruction cases pass |
| Physical-chip corpus, native minimum mode | 566,721 instruction cases pass |
| Physical-chip corpus, native maximum mode | 566,721 instruction cases pass |
| Directed architecture/control | 153 scenarios pass, including 128 ESC cases and four maximum-CX REP cases |
| Directed native pins | 25 minimum/maximum-mode bus, prefetch, arbitration and reset scenarios pass |
| Oracle negative controls | EU and native runners reject wrong expected IP and omitted expected writes |
| Encoding coverage | All 361 ledger rows assigned; no unassigned documented rows |
| Intel 1979 startup | Figure 2-63 initialization and reset far jump pass at every exact instruction boundary |
| Original Microsoft MS-DOS 1.25 DEBUG.COM | EU and both native modes each pass 22,100 RTL instructions and 1,239 external service calls |
| Yosys synthesis | Both tops synthesize, map and pass `check -assert` with zero structural problems |

The corpus total is **1,700,163 instruction-case executions** across the three interfaces. It covers 287 nonempty selected files from all 323 upstream files. Of 646,000 supplied cases, 77,256 upstream non-normal encodings and 2,023 undocumented segment-register fields are excluded explicitly. No test is removed because the RTL fails it. The [selection summary](vector_coverage.json) retains per-file counts and exclusion totals.

## Current historical-software rerun

On October 18, 2026, the current RTL (including the ESC/WAIT observation
outputs added for XT integration) was rebuilt and `run_software.sh` passed:
Intel's original startup sequence and unchanged Microsoft DEBUG.COM in the
execution unit, native minimum mode and native maximum mode. Each DEBUG
run executes 22,100 RTL instructions and 1,239 external service calls,
including register display, editing, disassembly, trap-based single steps
and normal exit. The software entrypoint now runs all three interfaces
without requiring the physical instruction-vector corpus. Linux shell
scripts are explicitly checked out with LF endings.

The complete `run_all.sh` was also rerun successfully on the current RTL:
strict lint, all nine formal tasks, eight UVM scenarios, 153 control tests,
25 native bus tests, all 1,700,163 physical-chip instruction-case executions,
oracle negative controls, historical software and both synthesis tops pass.
The retained completion log is `work/current-run-all.log`. These are the
same finite contracts and physical-oracle limitations described below.

## Independent instruction oracle

Expected results come from [SingleStepTests/8086](https://github.com/SingleStepTests/8086/tree/e71c68d215a6bb8c356bd4cb3842de3bef345ca9), captured on a physical Intel P80C86A-2. Downloaded artifacts are checked against pinned Git blobs. The converter copies captured architectural state and memory; it contains no instruction interpreter. The [reference record](../references/README.md) identifies the manufacturer documents, external artifacts and hardware methodology.

Every accepted fixture checks all registers, exact CS:IP, defined FLAGS, final RAM and ordered memory/I/O byte writes, including unchanged writes and absence of extra writes. Undefined flags use external metadata masks. Divide-error masks affect only the two saved FLAGS bytes, never saved CS:IP. A subsequent NOP must execute at the exact expected target and preserve the state. Negative controls verify that a wrong target or unlisted write actually fails the harness. Diagnostic vector filtering is disabled in sign-off scripts.

Native corpus runs seed the captured initial prefetch queue. Upstream's physical harness deliberately returns 90h for subsequent CODE fetches even where data RAM differs; fixture mode reproduces that external bus policy without changing data RAM or CPU behavior. Ordinary native tests and historical software use unified memory. Their self-modifying-code regression independently checks stale queued bytes and taken-transfer flushing. Original cycle counts and queue occupancy timelines are not compared because EU scheduling differs.

The manufacturer documents define the supported instruction set. Upstream metadata labels 0F as normal, but die-derived documentation identifies it as undocumented POP CS and the corpus supplies no 0F fixtures. The ledger records that disagreement and its exclusion. Register-indirect FF /2 CALL is documented but absent from the upstream generator, so a directed exact-target/return test supplies its evidence. WAIT, HLT, ESC and interrupt/control interactions also have dedicated directed tests.

## Historical software and control coverage

Intel's original six-instruction segment/stack startup is assembled with explicit linker values and packaged behind the reset far jump. Every instruction's expected IP and following opcode are checked. A final HLT is a test sentinel. See [software provenance](../tb/software/README.md).

The unchanged Microsoft DEBUG.COM binary is pinned to Microsoft's MS-DOS repository and SHA-256. All instructions execute in RTL. An external COM-loader/DOS fixture supplies process initialization, DOS services and a BIOS video-mode query; unknown services fail closed. The script displays registers, edits bytes to `B8 34 12 40 90`, disassembles them, performs three trap-based single steps, displays registers and quits. Assertions require the emitted bytes, AX=1234 then AX=1235, IP=0105, consumption of all input and normal termination. DEBUG installs and executes its own INT 1 handler, exercising real trap/IRET paths in all three interfaces. The emitted transcript is retained.

The 153 directed control scenarios check STI/IRET interrupt shadows, immediate CLI masking, NMI priority/nesting, TF sampling, all documented MOV/POP segment shadows, HLT wakeup, interruptible WAIT, partial REP state, original two-byte REP restart, LOCK/HOLD, vector/stack aliasing and register-indirect CALL. CL=255 checks ensure later-CPU count masking has not slipped in. Four full-CX REP byte/word moves run 65,535 elements in both directions and verify every write and final SI/DI/CX. All 128 ESC opcode/group/register-or-memory combinations check events, dummy reads and preserved architectural state.

Native tests independently check READY waits, odd word and port cycles, full/stale/flushed prefetch, uninterrupted INTA, AD floating and first-ACK BHE, LOCK, ownership across unlocked odd words, late requests, reset-release priority, reset in every active bus phase, RQ/GT0 priority and surviving RQ/GT1 requests. Pin assertions check address/data direction, output enables, strobes, wait-state status, T4 write-data holding and release/redrive gaps.

## Corrections and proof boundaries

Independent hardware fixtures corrected segment-offset word wrapping, invalid-BCD DAA/DAS adjustment, AAM divide-by-zero flags and the original IDIV range. Manufacturer documentation and original die-derived microcode pin interrupt-vector reads before stack writes, the two-byte REP interrupt restart and the requirement for an explicit LOCK prefix on original memory XCHG. These sources and assumptions are recorded beside the RTL and in the spec.

A separate datasheet audit found gaps in the initial native tests: unlocked odd words could yield between bytes, late ownership requests could be granted at T4, INTA did not fully float AD or drive first-cycle BHE correctly, and extended-wait status/T4 data holding needed correction. Dedicated pin tests now check these rules. Final review also replaced a wrapping prefetch generation bit with a persistent discard flag. A new independent formal monitor first produced a counterexample against the old implementation, then passed BMC and unbounded proof after the fix, with a reached two-redirect cover. See the [audit post-mortem](../../../failure_notes/2026-10-11-intel8086-native-bus-audit.md).

Formal safety leaves the relevant external inputs arbitrary after an initial reset. ALU properties cover mathematical arithmetic and defined flags. CPU properties cover reset entry, stable stalled requests, valid bus spaces/lanes, sticky diagnostic stop and quiet functional HLDA. A separate CPU ROM harness reaches fetch, retirement, write, HLT, fault, INTA and HLDA; its stimulus restrictions do not apply to the safety proof. BIU properties cover queue bounds, wait stability, output restrictions, ownership guards and abandoned-fetch suppression. All 18 cover goals are reached. These properties do not constitute a symbolic proof of every instruction's semantics.

## Practical limits and diagnostics

- This is a synthesizable digital model with explicit multiplexed pins/output enables. Original EU instruction-cycle counts, exact prefetch overlap, clock-edge analog delays, electrical limits and target-library timing closure are outside its contract.
- The independent instruction oracle uses CMOS P80C86A-2 silicon. Documented operations and selected extensions pass; general undocumented/NMOS behavior, including invalid-BCD equivalence, is not promised. Unsupported/invalid encodings enter diagnostic `fault_o`, which is not an original invalid-opcode exception.
- ESC supplies the original CPU-side bus/event behavior. Coprocessor arithmetic, an external 8288, board peripherals and a complete DOS operating system are outside this chip delivery. The DEBUG service fixture is documented explicitly.
- Synthesis uses `synth -noabc; abc -script +strash,map` and produces checked generic netlists for both tops. Generic cell counts are not physical area or maximum-frequency estimates.
- xezim emits 23 UVM component-name warnings with DPI disabled and a UVM phase-delay diagnostic. Explicit completion is reached with zero errors/fatals. RTL lint remains warning-free.

Ignored local evidence lives under `work/`: `current-run-all.log`, `run_all.log`, `lint/rtl.log`, `formal/*/status`, `uvm/uvm.log`, `vectors.log`, `vector_selection.json`, `reference/manifest.json`, `native/tests.log`, `native/vectors_min.log`, `native/vectors_max.log`, `software/startup.log`, `software/debug.log`, `software/native-debug.log`, software transcripts and `synth/*.log`. The deliberately failing pre-fix formal experiment is separate at `formal/prefetch_old_negative/`; it is not a sign-off task. Downloaded fixtures, binaries, netlists and build outputs are not committed.
