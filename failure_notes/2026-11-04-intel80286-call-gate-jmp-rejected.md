# 2026-11-04 - 80286 JMP through a call gate raised #GP instead of transferring

## What broke

In protected mode, a far JMP (`EA` or `FF /5`) whose selector names a call
gate always raised #GP(gate selector). `CALL_DESC_CHECK` rejected any call
gate when `protected_call_direct_jump` was set. Intel 210498-005 App. B page
B-54 ("JUMP TO CALL GATE") defines this transfer:
- The gate DPL must be at least max(CPL, RPL), or #GP(gate).
- The gate must be present, or #NP(gate).
- A nonconforming target needs DPL=CPL, and a conforming target needs
  DPL<=CPL, or #GP(CS selector).
- The target selector's RPL is not checked.
- CS:IP comes from the gate, the CS RPL becomes CPL, and no stack or link
  frame changes.

A latent second defect sat on the same path. A gate JMP would have reused the
direct-JMP CS-load completion (target 0). That completion compares the
completed request with the instruction's own pointer, not the gate's target.
It also passed `gate_call_i`, which accepts a more-privileged nonconforming
target and sets the CS RPL to that target's DPL. That is a privilege
escalation without a stack switch, but the first defect masked it.

The defect was found by auditing the RTL against the B-54 check list. The
regression suite did not find it.

## Why verification missed it

- No directed test executed a JMP through a call gate. The call-gate tests
  covered CALL only.
- The formal properties did not state the JMP-to-gate outcome. k-induction
  proves the stated properties, not unstated architecture.

## Fix

A gate JMP now reloads CS through its own code-load target (6):
- `gate_call_i` is off for the JMP.
- The gate's target selector is presented with RPL 0, so only the B-54 DPL
  rules apply. The checker sets the CS RPL to CPL.
- The completion compares against the gate's selector and offset.
- Faults use the existing #GP/#NP(CS selector) paths.

`protected_call_gate_jump` runs six CPL3 cases: a same-level target, a
conforming DPL0 target (CS RPL stays 3), and a nonconforming DPL0 target,
which raises #GP(0008h) through the TSS ring-0 stack. Each runs in both READY
modes. On the old RTL the first case raised #GP(0068h). `run_sim.sh` passes
226 tests. New formal properties tie target 6 to a gate JMP and check its
commit.

## Prevention

- For every Intel App. B transfer form (JMP or CALL to a code segment, call
  gate, task gate or TSS), keep at least one directed test per destination
  type. A missing destination row is a test-plan defect.
- When one engine serves several instructions, check every caller-specific
  input (`gate_call_i`, `call_i`, `stack_i`, expected request) per caller.
