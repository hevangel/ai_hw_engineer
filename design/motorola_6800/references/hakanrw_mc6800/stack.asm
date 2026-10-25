    LDX #$1FFF       ; Initialize stack pointer to $1FFF
    TXS              ; Transfer X to SP
    LDAA #42         ; Load 42 into A
    LDAB #84         ; Load 84 into B

    PSHA             ; Push A onto the stack
    PSHB             ; Push B onto the stack

    LDAA #0          ; Clear A
    LDAB #0          ; Clear B

    PULA             ; Pull A from the stack -> A = 84
    STAA $2000       ; Store A (84) in $2000
    PULB             ; Pull B from the stack -> B = 42
    STAB $2001       ; Store B (42) in $2001
