# Intel 8080 implementation plan

1. Establish Intel's documented architecture and functional bus boundary
   before RTL. Resolve ANA/ANI from Intel's later 8080/8085 manual; record
   ambiguous interrupt details and excluded silicon behaviors explicitly.
2. Adapt the verified Am9080 controller into independent Intel modules. Keep
   the AMD design unchanged; this first implementation favors a reviewable
   adaptation over a shared-core refactor affecting both processors.
3. Implement Intel ANA/ANI AC in the ALU. Use the existing pinned, unmodified
   external Intel emulator directly, without the AMD adapter. Share the
   vendored oracle by repository-relative path rather than duplicate it.
4. Adapt exhaustive ALU tests, all 244 documented opcode tests, exact PC and
   actual next-executed-instruction checks, UVM and formal proof/cover.
   Add explicit ANA/ANI operand-bit-3 cases to catch the AMD/8085 differences.
5. Run original TST8080.COM and 8080PRE.COM through the functional bus and
   compare every retirement and memory/I/O effect against independent traces.
   Verify hashes; never patch diagnostic instruction bytes.
6. Complete lint, formal, ALU/opcode/software simulation, UVM and synthesis.
   Record actual results and remaining limitations before submitting a PR.
7. Subsequent milestones: Intel-specific multi-byte interrupt evidence,
   undocumented aliases, native T-state/pin adapter and an historical
   machine/firmware system build. They are not sign-off claims for this core.

Module hierarchy: `intel_8080` instantiates `intel_8080_alu`. Runtime RTL has
no dependency on the AMD design; only verification shares its immutable
third-party C oracle. Test/build outputs belong in ignored `work/`.
