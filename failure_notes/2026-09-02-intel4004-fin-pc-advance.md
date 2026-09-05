# intel_4004 FIN program-counter advance

- **Date found:** 2026-09-02
- **Found by:** original BUSICOM 141-PF firmware running on the reconstructed
  board (system/busicom_141pf) — not by any design verification
- **Fixed in:** PR #10 (system/add-busicom-141pf), commit c60e714 and later
- **Design touched:** design/intel_4004 (RTL, TB reference model, formal
  golden model)

## What happened

Every `FIN` instruction skipped the instruction that followed it. The 4004
design advanced the program counter by two for FIN; FIN is a **one-word
instruction executed over two cycles**, so the correct advance is one. The
first FIN executed by the real firmware derailed the machine — in the
BUSICOM 141-PF, FIN *is* the pseudo-code engine's instruction fetch, so
nothing worked.

## How it escaped verification

The 4004's verification suite is agreement-checking: the RTL must match an
instruction-set simulator (ISS) cycle-for-cycle and a formal golden model
state-for-state, backed by exhaustive per-instruction tests. All three
artifacts encoded the same wrong rule:

| artifact | the shared bug |
|---|---|
| RTL (`intel_4004.sv`) | `pc_next = cycle2 ? pc_plus2 : pc_plus1;` |
| TB ISS (`tb_intel_4004.sv`) | `iss_stack[iss_sp] = iss_c2_prev ? pc2 : pc1;` |
| formal golden model (`intel_4004_props.sv`) | `g_stack[g_sp] <= g_cycle2 ? g_pc2 : g_pc1;` |

Every other two-cycle instruction in the ISA (JCN, JUN, JMS, ISZ, FIM) is
also a two-*word* instruction, for which `+2` is correct. FIN is the lone
exception — one word, two cycles, `+1`. The uniform rule captured the
generalization and missed the exception, and it was copied into the
reference models, so every check compared the RTL against a mirror of its
own mistake.

Three things made it stick:

1. **FIN's datapath was correct.** The pair-0 indirect address, same-page
   fetch, and the load into the destination pair all matched between RTL and
   model. Only the final PC was wrong, and both sides were wrong identically.
2. **Land-tolerant test programs.** The FIN test sequences had executable
   padding after the FIN (a JUN whose operand byte was itself executable,
   NOP landing fields in the page-straddle cases). Wherever the PC landed,
   RTL and ISS executed the same mirrored sequence and reached the same
   park state. A test that passes under two different semantics tests
   neither.
3. **No post-instruction PC assertion against an external source.** The TB
   compared the RTL's PC to the ISS's PC — both derived from the same rule
   — never to an architectural truth table written independently.

The formal suite likewise proves RTL ≡ golden model. Equivalence against a
co-authored model verifies implementation consistency, never specification
correctness.

## How it was found

The original BUSICOM 141-PF firmware places live instructions directly
after FIN (in fact the firmware's pseudo-code interpreter `fin 1<` at $300
is executed constantly). The first FIN derailed the machine visibly: keys
registered in RAM, the printer never fired. Diagnosis chain, in the order
that worked:

1. Reproduce with a minimal Rust harness built on the *reference emulator's*
   chip crate — it stalled identically to the RTL, proving the shared host
   protocol was fine and isolating the fault to chip behavior shared by
   both (initially suspected, wrongly, to be per-cycle host timing).
2. Authoritative contract: the Kintli disassembly of the recovered firmware
   (4004.com rel-1-0-1) shows live code at $037 immediately after the FIN at
   $036, and FIN used pervasively ($300, $036, $03b, $2005-area) — any skip
   breaks the interpreter, so FIN must land at PC+1.
3. PC-anchored traces on the RTL (`pc == 0x029` / `pc == 0x037` breakpoints)
   showed the scan code arriving intact at $029 and PC never reaching $037.

Fix: RTL advances PC by one when `fin_word`; the ISS was corrected
identically; the formal golden model's advance was corrected and the full
4004 suite (sim, formal bmc/prove/cover, lint, synth) passes with the
corrected semantics.

## Was the spec misread?

Partly — the more precise statement is that the spec leaves FIN's
post-instruction PC unstated, and the rule was generalized from the
neighboring instructions:

- The Intel MCS-4 documentation describes FIN as one word, two cycles,
  address from index pair 0, result into the pair named in the opcode. It
  does not spell out the resulting PC value.
- The real 4004 increments PC at A1 of *every* cycle; during FIN's second
  cycle that increment is reused to present the indirect address instead of
  PC+1. A model reasoned as "PC ticks every cycle, and FIN takes two
  cycles" lands on +2. The net architectural effect is +1.
- FIN is the only two-cycle/one-word instruction in the ISA — the exception
  to a rule that holds for the other five two-cycle instructions.

## Prevention plan

1. **Real-software regression is mandatory for CPU designs.** A chip whose
   spec was exercised by real historical software must run that software in
   its `run_all.sh` regression. For the 4004, the BUSICOM firmware
   bring-up is now part of system/busicom_141pf's tests and exercises the
   MCS-4 designs; per-instruction agreement with a self-written model does
   not count as architectural proof.
2. **Independent-oracle rule for reference models.** The ISS and formal
   golden model of a CPU must be derived from an external artifact
   (manufacturer disassembly table, a third-party emulator, or recovered
   code traces) — never by re-reading the RTL or from the same session's
   reading of the manual. When the model must change together with the RTL
   (as here), the change citation must reference the external source that
   pins the new behavior.
3. **Assumption ledger.** Any behavior the primary documentation does not
   explicitly state gets an `ASSUMPTION:` comment in the RTL, an entry in
   the design spec, and a validation task against real code before
   sign-off. FIN's PC advance would have been flagged as an assumption.
4. **No land-tolerant CPU tests.** Instruction tests must assert the exact
   post-instruction PC and the exact next-executed instruction. Landing
   pads (NOP fields, executable operands, "park" loops placed to absorb
   unknown PC landing) in CPU tests are a defect in the test and now fail
   review.
5. **Failure note on every escaped bug**, with the external oracle named —
   this note is the first entry; the convention lives in
   `failure_notes/README.md`.
