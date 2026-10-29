# MOS Technology 6502 physical-bus variant

The 6502 was introduced in **1975** and powered the Apple II, Commodore PET
and many other early computers. Its inexpensive, efficient instruction set
helped make personal computing practical. The year is supported by the
[IEEE historical exhibit](https://history.ieee.org/programs/ieee-global-museum/microchips-that-shook-the-world/).
An exact commercial introduction day is not asserted here.

This authored, synthesizable NMOS implementation supports **all 151 documented
opcodes**, their bus cycles, NMOS decimal flags, stack, interrupts, reset,
RDY and SO. The other 105 opcodes latch `fault_o`; undocumented silicon
behavior is outside this design's acceptance contract.

The physical 40-pin adapter executes the **unchanged original Apple II Monitor**
on the [wired revision-0 motherboard](../../../../system/apple_ii), including keyboard
commands, display output and cassette byte routines. No external CPU executes
instructions in the authored motherboard regression.

## Run and evidence

From this folder, in the Apple II tools image, run `sh scripts/run_all.sh`.
It runs lint, formal BMC/prove/cover, directed tests, independent bus vectors,
exhaustive arithmetic, transistor pin comparisons, synthesis, and historical
Monitor/display/cassette regressions. Network access is needed on a fresh
cache; pinned external artifacts remain in ignored `work/`.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification report and limits](report/final_report.md)
- [Independent artifact ownership and pins](tb/REFERENCES.md)

Instruction behavior is grounded in the MOS
[January 1976 programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf)
and [hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf).
Independent external artifacts validate semantics and physical pin timing;
no golden instruction model is derived from the RTL.

## Integration with the functional core

This is the physical-bus implementation preserved from the Apple II branch at aabbf67. Its module is named mos_6502_cycle to allow both implementations to coexist. The [functional-bus core](..) retains its independently completed Klaus regression. The physical motherboard uses this variant because it requires NMOS dummy cycles and physical reset/RDY/SO pins. Verification claims belong to each variant's own report; the functional core's Klaus pass is not a pass for this variant.


## Roadmap ownership

Chip member: [ai_engineer#267](https://github.com/hevangel/ai_engineer/issues/267); canonical parent [#33](https://github.com/hevangel/ai_engineer/issues/33). Multiple models of the same chip use this one member issue.
