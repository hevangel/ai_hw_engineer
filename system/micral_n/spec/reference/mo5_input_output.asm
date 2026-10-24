; Send data to I/O
;
; Notation note (2026-10-23): the shipped binary drives output device 23
; (opcode 0x6F, i.e. port /17 hexadecimal = 23 decimal in the R2E map), not
; the "015" written below — MO5's source notation and its assembled binary
; disagree, and this comment preserves both. The platform's spec documents
; /17 as hexadecimal.

START:
    ORG 0x0000
    LAA ; Starts with a NOP
    LBI 0x00
WAIT:
    ; Waits for a a signal on the input #5 (sending it 0x80)
    LAI 0x80
    INP 0x5
    ORA
    JTZ WAIT

    ; Outputs the value of B on output #1/5
    LAB
    OUT 015
    INB
    JMP WAIT
