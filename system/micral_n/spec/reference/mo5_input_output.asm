; Send data to I/O

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
