# Historical Intel startup regression

Source: Intel, *8086 Family User's Manual*, October 1979, figure 2-63, **Typical ASM-86 Program Organization**, chapter 2. [Intel-authored scan](https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_family_Users_Manual.pdf).

The historical executable sequence is six instructions:

```asm
MOV AX, DATA_SEG
MOV DS, AX
MOV ES, AX
MOV AX, STACK_SEG
MOV SS, AX
MOV SP, OFFSET STACK_TOP
```

The manual leaves segment placement to LOC-86 and specifies 100 words of stack. The test supplies CODE_SEG=1000h, DATA_SEG=2000h, STACK_SEG=3000h and STACK_TOP=00C8h. It supplies the far jump at FFFF0h described in the accompanying text. `startup.S` expresses those same instructions in GNU assembler syntax; GNU `as` assembles the binary independently of the RTL. The HLT after the historical sequence is a test completion sentinel. The harness checks the exact PC at every retirement and checks the next fetched opcode, with no landing-tolerant padding.

Only syntax, linker constants, reset-vector packaging and the completion sentinel are test adaptations. The source instruction sequence is historical manufacturer software. It is small, and full-CPU application-level sign-off remains a later milestone.
