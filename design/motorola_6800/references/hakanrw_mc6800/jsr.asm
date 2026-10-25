START:
    LDS #$1FFF       ; Initialize SP to $1FFF
    JSR SUBROUTINE   ; Branch to SUBROUTINE

    LDAA $200A       ; Load the value written by the subroutine into A
    STAA $2000       ; Store A into $2000 to verify the value

    LDAA $1FFF       ; Load the return address from the stack
    STAA $2001       ; Store low byte of return address in $2001
    LDAA $1FFE       ; Load the high byte of the return address
    STAA $2002       ; Store high byte of return address in $2002

    BRA END          ; Skip the subroutine

SUBROUTINE:
    LDAA #42         ; Load 42 into A
    STAA $200A       ; Write 42 to $2000
    LDAA #0
    RTS              ; Return from subroutine

END:
    NOP              ; End of the program
