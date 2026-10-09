# Intel 8086 — first milestone report

## Outcome

The initial segmented CPU subset is implemented and verified. **This is not a complete 8086 or a pin-compatible replacement.** The exact supported encodings and functional bus contract are in the [specification](../spec/spec.md); the [implementation plan](../plans/implementation_plan.md) records the remaining instruction, interrupt and BIU milestones. No system/board design was added.

Final verification ran on 2026-10-08 in `ai-hw-engineer:latest`, with Verilator 5.052, Yosys 0.69 and xezim 0.11.0. SymbiYosys used ABC BMC/PDR, Z3 for ALU properties and Yices for CPU covers; UVM was Accellera 1800.2-2017. The complete command exited zero:

```sh
sh design/intel_8086/scripts/run_all.sh
```

## Results

| Check | Result |
|---|---|
| Verilator `--lint-only -Wall` | Pass, no RTL warnings |
| ALU BMC/prove/cover | All pass; mathematical byte/word arithmetic and flag equations, three reached cover goals |
| CPU BMC/prove/cover | All pass; BMC depth 24, unbounded ABC PDR safety proof, five reached cover goals |
| xezim/UVM | Eight control/boundary scenarios; zero UVM errors/fatals |
| Independent physical-chip vectors | **361,977 pass** across 182 files, with deterministic ready stalls |
| Oracle negative controls | Wrong expected IP and removed expected write list both rejected |
| Historical software | Intel 1979 manual figure 2-63 startup passes through reset far jump and all exact instruction boundaries |
| Yosys synthesis and `check -assert` | Pass; zero reported structural problems; 4,924 generic cells including ALU, not a technology area/timing estimate |

The hardware suite starts with 364,000 cases in the selected files. It excludes 2,023 undocumented segment-register fields (8C/8E reg=4–7 and MOV CS); no other exclusion category was triggered. Every remaining case compares all registers, exact CS:IP, defined flags, final memory and ordered byte-write effects from the hardware bus trace. After each non-HLT fixture, the harness installs and executes one NOP at the exact expected next address and checks its retirement and preserved state. There is no padding to tolerate wrong branch destinations. HLT is absent from the upstream corpus and is covered by UVM and formal reachability.

Hardware data is pinned to SingleStepTests/8086 commit `e71c68d215a6bb8c356bd4cb3842de3bef345ca9`, with Git-blob verification before conversion. See [reference provenance](../references/README.md) and the generated [selection counts](vector_coverage.json). Expected instruction results come from physical silicon, not a self-written interpreter. Cycle timing and prefetch queues are not compared; the ordered memory-write oracle uses captured cycles only to recover byte addresses, values and ordering.

UVM exercises segment-offset word wrap, SS defaults for BP addressing, signed disp8, DS override, LEA, original PUSH SP/POP SP semantics, 20-bit physical wrap, instruction-IP wrap, reset during a long stalled write, HLT idling and explicit unsupported LOCK/MOV CS stops. Its seven required control observations (reset, stall, both byte lanes, write, halt and fault) all occur.

The cover-only ROM harness executes PUSH AX followed by either HLT or unsupported 60h, with reset once and READY high. The safety proof keeps read data, READY and later resets arbitrary. Cover stimulus restrictions do not apply to that proof.

The historical regression preserves Intel's six-instruction segment/stack initialization sequence, assembled by GNU binutils with explicit linker values, plus reset-vector packaging and a test HLT sentinel. Every exact retirement IP and next fetched opcode is checked. See [software provenance and adaptations](../tb/software/README.md). This small routine establishes startup behavior only; it does not establish application-level compatibility.

## Boundary correction found by this suite

The first hardware-vector run rejected A1.json.gz case 1633, `MOV AX, word [ES:FFFFh]`. The initial implementation incorrectly advanced the physical address for the high byte. Physical silicon reads the high byte from offset 0000h in the same segment. RTL now calculates each byte's segmented address with 16-bit offset wrap; the spec cites the independent fixture and UVM explicitly checks the corresponding store/load boundary. This was found by the design's own regression before review, not an escaped defect.

## Limitations and diagnostics

- Decimal adjust, strings/REP, shifts/rotates, multiply/divide, calls/returns, software/hardware interrupts, I/O, WAIT/ESC and undocumented aliases remain outside the subset. Unsupported encodings assert sticky `fault_o`; this is not an original 8086 invalid-opcode exception.
- TF/IF are stored FLAGS bits only. Interrupt/trap recognition, interrupt shadows, HLT wakeup, HOLD/HLDA and LOCK atomicity are later milestones. Reset currently exits HLT/fault.
- There is no six-byte prefetch queue or native minimum/maximum-mode timing. Words use two byte-lane transactions even when aligned. Prefetch-sensitive/self-modifying-code compatibility is not claimed.
- The independent oracle uses a CMOS P80C86A-2. Passing documented operations does not establish all differences from original NMOS silicon.
- No full historical application or operating system has been signed off. Before full architectural sign-off, run unchanged original application binaries and expand the [assumption ledger](../spec/spec.md#assumption-ledger)'s validation.
- xezim reports 23 UVM component-name warnings with DPI disabled and its UVM phase-delay diagnostic. The test reaches its explicit completion marker with zero errors/fatals. ABC prints combinational-network notices during synthesis. These diagnostics are retained in the logs; the RTL lint is warning-free.

Ignored local evidence is under `work/`: `run_all.log`, `lint/rtl.log`, `formal/*/status`, `uvm/uvm.log`, `vectors.log`, `vector_selection.json`, `reference/manifest.json`, `software/startup.log` and `synth/synth.log`. Downloaded fixtures, compiled simulators and netlists are not committed.
