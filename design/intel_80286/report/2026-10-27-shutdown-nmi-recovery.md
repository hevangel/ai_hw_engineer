# Protected shutdown NMI recovery checkpoint

**Date:** 2026-10-27 13:23 UTC  
**Scope:** NMI exit from protected 80286 shutdown  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)

## Architectural rule

Intel's [80286 and 80287 Programmer's Reference Manual, order 210498-005,
§§9.6.2 and 11.6](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
specifies that NMI or RESET can leave shutdown, INTR is ignored, and a fault
while processing the shutdown NMI leaves RESET as the only exit. The NMI
handler must therefore pass ordinary protected IDT, target and frame checks
before shutdown is cleared.

## Implementation

The event controller now has a shutdown-only NMI selection path. It accepts a
pending or newly sampled NMI as vector 2 regardless of IF, current NMI blocking,
instruction-boundary inhibition or single-step priority; it never requests an
INTR acknowledgement in shutdown. The core allows protected event bus traffic
while attempting that NMI, but retains an internal shutdown latch until the
NMI frame and handler context commit. A diagnostic stop or a nested exception
while processing the NMI re-enters shutdown, suppresses the diagnostic fault
output, and disables further NMI wake attempts until RESET. Successful
protected event commit clears shutdown; a later HLT remains an ordinary HLT.

## Directed evidence

`--shutdown-nmi` runs immediate and stalled READY cases. They verify:

- INTR cannot wake shutdown or request acknowledgement.
- A valid protected vector-2 interrupt gate exits shutdown, writes the exact
  FLAGS/CS/IP frame, reaches the handler and executes its MOV and HLT.
- Invalid vector-2 gate contents, a vector-2 IDT-limit failure and an invalid
  target code descriptor each return the CPU to shutdown without a partial
  exception frame or visible diagnostic fault.
- A second NMI cannot leave shutdown after the first NMI attempt faults;
  RESET clears shutdown.

The expanded `--iopl-controls` suite and the complete default Verilator
bootstrap pass on the exact runner recorded below. Strict lint and source
preflight also pass. The standalone event-controller suite passes 8,016
checks. Its current-source SymbiYosys BMC, k-induction and cover tasks pass;
the shutdown NMI cover is reached. These are event-controller proofs only and
do not establish a connected-core proof.

Commands and retained evidence:

```text
verilator --lint-only -Wall --top-module intel_80286 src/*.sv                 PASS
python3 scripts/preflight.py                                                  PASS
work/shutdown_nmi_20261027_03/Vintel_80286 --shutdown-nmi                    PASS
work/shutdown_nmi_20261027_03/Vintel_80286 --iopl-controls                   PASS
work/shutdown_nmi_20261027_03/Vintel_80286                                   PASS
standalone event-control Verilator runner                                    PASS (8,016 checks)
sby intel_80286_event_control.sby bmc                                        PASS
sby intel_80286_event_control.sby prove                                      PASS
sby intel_80286_event_control.sby cover                                      PASS
```

The runner manifest, focused logs and full bootstrap log are in
`work/shutdown_nmi_20261027_03/`. The standalone controller log and SBY task
logs/traces are in `work/shutdown_nmi_20261027_01/`.

| Artifact | SHA-256 / count |
|---|---|
| Core RTL | `622a6e4905c9cd340b688db2ceb7764f371ea964f33302e1c570d83e25cee7e2` |
| Event-controller RTL | `42bc55f90ac7faa0ea21a42b5b095934b933c355639dc2fe69225aaaf7c4c9ca` |
| CPU testbench | `1e4302ab9875973b998665716333a425a7d4c06d63ec22b0c8a77d12c0ac81b9` |
| Event-controller testbench | `57a19196cc953685aa5d86dab72910535ebe3e220405e13520551b7e52655e85` |
| Core properties | 305 assertions, 1 assumption, 52 covers; SHA-256 `60bfaa205b3c36c21e7dee19fe9d909eb6a8d4a118e249545ccb081cb5fdf4f3` |
| Event-controller properties | 13 assertions, 1 assumption, 7 covers; SHA-256 `b5d6623483db226bcc36d45df4d30f84e5b5f91aff49e4973b0bee5548c4e0a1` |
| Reviewed property inventory | SHA-256 `f1b6bc26d773fa0212fa39a46ae710b6cd249aa136fd141826238ce4c8a67032` |
| Verilator runner | SHA-256 `214ad713ec746c1850d33fa17efbc9011a897e54d327780f966f8fd7af83787d` |
| Runner fingerprint | `ddbcb2ae9fc7417baa471c1b35e216185af51df3d090682105f3c4e616f74249` |
| Tools | Verilator 5.052, g++ 15.2.0, SymbiYosys 0.70, Yosys 0.69, Z3 5.1.0 |

## Remaining limits

The directed cases cover three NMI-delivery failure phases, not every gate,
target-task, segment, stack or memory failure combination. The external
shutdown HALT bus cycle remains outside the byte-transaction interface. No
current-source connected-core BMC, prove, cover or PDR result has evaluated
this RTL/property pair; the older `_21` connected-core cover and PDR jobs are
still running on earlier snapshots. Synthesis, the full #DF generation and
delivery matrix, task-switch reset cuts, independent historical-software
regression, and the full release gate remain open. Full 286 completion is not
claimed.
