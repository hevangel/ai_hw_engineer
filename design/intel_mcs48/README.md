# Intel MCS-48 family

Canonical issue: [#256](https://github.com/hevangel/ai_hw_engineer/issues/256). One family folder; one native sub-issue per identified physical chip.

| Chip | Member issue | Implementation / sourced history |
| --- | --- | --- |
| 8042 (UPI-42) | [#257](https://github.com/hevangel/ai_hw_engineer/issues/257) | [intel_8042](intel_8042/README.md) |

Historical dates, source qualifications and verification limits remain in member READMEs and the [design index](../README.md). The UPI-42 is the 2K-ROM member of Intel's Universal Peripheral Interface line, which shares the MCS-48 instruction set with slave-interface additions. Other members (8048/8049 microcontrollers, the 1K 8041A/8741A) are not implemented. The 8042's processor core (`intel_8042/src/upi42_core.sv`) takes its program memory through a port so later members can reuse it.
