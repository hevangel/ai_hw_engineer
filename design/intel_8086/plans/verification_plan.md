# Intel 8086 verification plan

`scripts/run_all.sh` runs strict RTL lint, all formal tasks, UVM, the independent corpus, directed architectural controls, historical software, both native modes and synthesis. It fails on command errors or missing completion/count markers. A generated encoding ledger rejects unassigned documented rows. Actual results belong in the [report](../report/final_report.md).

## Independent physical-chip expectations

Use [SingleStepTests/8086](../references/README.md), pinned by commit and Git-blob hashes. The converter copies captured expected registers/RAM and merges partial final updates; it contains no instruction interpreter. Per-opcode masks exclude only undefined flags. Divide-error masks are restricted to the two stack FLAGS bytes. ALE-latched addresses, BHE and T3 write data produce an ordered byte-write oracle for memory and I/O, including unchanged writes.

Every accepted fixture compares all registers, exact CS:IP, defined flags, RAM, write addresses/values/order/count and absence of unlisted writes. After that comparison, the harness executes one NOP at the exact expected target and checks the next IP and preserved state. There is no tolerance for a wrong landing. Negative controls corrupt expected IP and delete the expected write list; both the EU and native runners must reject them. Diagnostic vector filtering is disabled in the sign-off scripts, and the exact converted fixture count must match the completed run.

Run the corpus through three interfaces: direct EU transactions, native minimum mode and native maximum mode. The native runners inject the captured initial architectural state and six-byte queue, as upstream recommends, then drive only the external AD/READY/pin responder for execution. Upstream explicitly returns 90h for CODE fetches following the tested instruction, even if data RAM at the same address differs. Native fixture mode reproduces that external hardware harness policy; it does not rewrite data RAM or change the CPU. Ordinary native/software tests use unified RAM and independently check stale prefetch and taken-transfer flushing. Original cycle counts, queue occupancy timelines and prefetch overlap are not compared, because EU scheduling differs.

Selection excludes upstream non-normal encodings and undocumented segment fields/MOV CS, with every count retained. Manufacturer documentation, rather than an upstream metadata label, determines documented scope: 0F is known undocumented POP CS, omitted from the upstream corpus. The ledger records that disagreement explicitly. FF /2 register CALL is missing from the upstream generator and has a directed exact-target/return test.

## Historical software

Run Intel's figure 2-63 segment/stack startup through the reset far jump, checking every instruction's exact PC and opcode. Run unchanged, hash-verified Microsoft MS-DOS 1.25 DEBUG.COM through the EU and both native modes. A documented external fixture supplies COM-loader state, DOS services and the BIOS video-mode query; it does not interpret instructions or replace the application's debugger. Script register display, hex memory edit, disassembly, three trap-based single steps and quit. Require the exact emitted instruction bytes, AX=1234 then AX=1235, IP=0105, all input consumed and a normal exit. Unknown external service requests fail closed. Keep the output transcripts.

## Directed controls and native pins

UVM covers segment/physical/IP wrap, BP segment defaults, disp8, override, LEA, PUSH/POP SP, reset during stalls, halt/fault and accepted transfers. Its protocol-only driver and independent scoreboard check stable stalled state and exact outcomes.

The C++ control suite adds STI/IRET shadows, immediate CLI masking, NMI priority/nesting, TF sampling, all documented MOV/POP segment shadows, HLT wakeup, busy/interruptible WAIT, partial REP state and the original two-byte restart quirk, LOCK/HOLD, vector/stack aliasing, register-indirect CALL, full-byte CL=255 and all 128 ESC opcode/group/operand cases. Four REP tests exhaust CX=65535 for byte/word moves in both directions, checking every ordered write and exact final SI/DI/CX. Each directed instruction checks the exact expected post-PC and subsequent instruction address.

Native tests cover both modes, odd word and port transfers, READY waits, a full queue, self-modifying code with stale bytes and a taken-jump flush, two uninterrupted INTA cycles, AD floating/BHE during INTA, LOCK arbitration, unlocked odd-word ownership, late requests after T2, reset-release ownership priority, reset in T1/T2/T3/Tw/T4 and RQ/GT0 priority with a surviving RQ/GT1. Check strobes, AD direction/output enables, active status through waits, T4 data holding, QS observations and release/redrive gaps.

## Formal and synthesis

ALU properties check mathematical byte/word arithmetic and defined flags, with carry/overflow/zero covers. CPU safety proves reset entry, stable stalled requests, valid lanes/spaces, sticky diagnostic stop and quiet HLDA with arbitrary read data, READY, interrupts, ownership requests and subsequent resets. Its separate reachability ROM witnesses fetch, retirement, write, HLT, fault, INTA and HLDA. Assertions are removed only from this cover-only model; the unconstrained safety model remains separate.

BIU safety proves queue/pointer bounds, stable waited cycles, correct output-enable restrictions, INTA floating, status during waits, odd-word ownership inhibition, single-channel grants and discard of any redirected in-flight prefetch. An independent formal monitor remembers abandonment until the cycle finishes; the old one-bit generation implementation fails this property after two redirects. Covers witness waits, a full queue, simultaneous queue pop/refill, ownership loss, both grant channels, a flush during an active prefetch and completion after two redirects. Run BMC, unbounded prove and cover for ALU, CPU and BIU; all cover goals must be reached. These are specified safety proofs, not a full symbolic proof of every instruction.

Strict Verilator `-Wall` lint checks the complete native hierarchy; the EU build also uses `-Wall`. Yosys synthesizes and runs hierarchy/check assertions for both tops. Generic mapping uses `synth -noabc; abc -script +strash,map` to avoid expensive default fraiging of combinational division. This still produces a checked generic netlist; cell counts are not target-library area or timing closure. The tool image supplies all HDL tools, UVM, GNU binutils and Python. First-run downloads need GitHub HTTPS; cached artifacts are integrity-checked.
