# Historical 8086 software regressions

## Intel segment/stack startup

Source: Intel, [8086 Family User's Manual, October 1979](https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_family_Users_Manual.pdf), figure 2-63, **Typical ASM-86 Program Organization**. The six instructions initialize AX/DS/ES, AX/SS and SP. `startup.S` changes assembler syntax only; the fixture supplies CODE_SEG=1000h, DATA_SEG=2000h, STACK_SEG=3000h, STACK_TOP=00C8h, the documented reset-vector far jump and a completion HLT. GNU binutils assembles it independently of RTL. Every retirement IP and next opcode is checked without landing-tolerant padding.

## Unchanged Microsoft DEBUG.COM

Source: Microsoft's MIT-licensed [MS-DOS repository](https://github.com/microsoft/MS-DOS/tree/2d04cacc5322951f187bb17e017c12920ac8ebe2/v1.25/bin), commit `2d04cacc5322951f187bb17e017c12920ac8ebe2`, `v1.25/bin/DEBUG.COM`. Downloaded binary: 5,999 bytes, SHA-256 `217b59ff054a238ace99c51831e227c9edfe0c0c6925a51c99a2d0c6107402ef`. `scripts/prepare_software.py` verifies that hash and retains the [Microsoft MIT license](https://github.com/microsoft/MS-DOS/blob/2d04cacc5322951f187bb17e017c12920ac8ebe2/LICENSE) in ignored `work/software/`.

The binary's bytes are never patched or reassembled. A chip test fixture establishes the normal COM-loader registers, stack, PSP and empty command tail. External INT 20h/21h services provide console I/O, vectors, PSP creation and DOS environment behavior; INT 10h supplies the video-mode query. These hooks model the application's environment, never CPU instructions. Unknown requested services fail closed. All DEBUG instructions, its disassembler, parser and trap handler execute in RTL, including its own INT1 installation, IRET and trap-driven return to the command prompt.

The script runs register display (`r`), hex edit (`e 100 b8 34 12 40 90`), disassembly (`u 100 104`), three single steps (`t`), another register display and quit (`q`). Assertions require decoded bytes `B83412`, AX=1234 after MOV, AX=1235 after INC, IP=0105 after NOP, complete command consumption, no startup file error and normal exit. No broad PC padding or instruction emulation is used.

Run this original application through the direct EU interface and both native bus modes, with READY backpressure. Ordinary software mode uses unified code/data RAM, unlike the specialized upstream physical-vector responder. Preserve `work/software/debug.log`, `native-debug.log` and `debug_transcript.log` for inspection. This is an application regression with a service fixture, not a complete DOS/PC system.
