# Verification plan

`scripts/run_all.sh` runs RTL lint, formal BMC/prove/cover, simulation, independent hardware vectors, historical software and Yosys synthesis. Every command fails closed on errors or incomplete run markers. Read the final report for actual results.

## Independent expectations

Use the MIT-licensed SingleStepTests/8086 corpus pinned in [the provenance file](../references/README.md), not an ISS derived from this RTL. The fixture converter merges partial final register updates with the initial state, respects per-opcode undefined-flag masks and rejects unsupported prefix/operand forms. Every accepted fixture compares all architectural registers, exact CS:IP, defined flags, final memory, and every actual memory write (no unlisted writes). Tests then execute a deliberately installed single NOP at the exact expected next location and check the next IP. Installing that NOP happens only after the original fixture has passed, so it cannot absorb a wrong branch landing.

Run all tests in the accepted files; report exclusions with reasons. Native memory-write cycles are expanded into ordered byte effects using ALE-latched addresses and BHE lanes, and compared exactly, including writes that preserve a byte's value. Queue contents and hardware cycle counts are deliberately not compared because this is the functional milestone. Fetches come from the fixture's RAM, which must agree with its queued instruction bytes; incompatible prefetch cases are excluded and counted explicitly. Negative controls must reject a corrupted expected IP and a removed expected write list.

## Historical software

Run Intel's original segment/stack initialization example from figure 2-63 of its 1979 manual, assembled with explicit segment locations and reached through a reset-vector far jump. Verify each exact instruction address and the next instruction, all initialized segments, SP and absence of faults. This is actual manufacturer software, with linker values supplied by the test; it is not a substitute for the later full application regression.

## Directed and formal checks

- UVM sequences drive a memory responder's stall policy; a protocol-only driver responds to bus transactions. A scoreboard checks instruction outcomes, exact IP and writes. Cover reset entry, long stalls, lane selection, segment overrides, displacement sign extension, IP wrap, 20-bit wrap, original PUSH SP, POP SP and unsupported encodings.
- Formal proves ALU arithmetic/logic flags against mathematical equations and covers carry/overflow/zero outcomes. CPU safety properties check reset entry, aligned single-lane transfers, stalled-request stability and terminal states with arbitrary read data, READY and subsequent resets. The separate cover task instantiates `formal/intel_8086_cover.sv`: reset once, READY high and a repeating ROM word containing PUSH AX followed by either HLT or unsupported opcode 60h. Safety assertions are removed only from that reachability model after flattening; their complete unconstrained proof runs separately. Both alternatives must reach their terminal states, and the task must cover fetch, write and retirement. These stimulus restrictions apply only to reachability, never to the safety proof.
- Verilator `-Wall` lint and Yosys `check -assert` guard width, latch and synthesis issues. The tool image supplies Verilator, xezim/UVM, SymbiYosys/ABC/Z3/Yices, Yosys, GNU binutils and Python 3. First-run fixture download needs HTTPS access to GitHub; cached files are checked on every run. No timing closure or native-pin correctness is implied.
