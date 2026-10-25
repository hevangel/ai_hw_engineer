    LDX #$1FFF       ; Initialize SP at $1FFF
    TXS              ; Transfer X to SP

    LDAA #10         ; Load 10 into A
    PSHA             ; Push A onto stack

    LDAB #20         ; Load 20 into B
    PSHB             ; Push B onto stack

    INS              ; Increment SP -> Skip over B
    PULA             ; Pull A from stack -> Should retrieve 10
    STAA $2000       ; Store A (10) in $2000

    DES
    DES              ; Decrement SP to original position
    PULB             ; Pull B from stack -> Should retrieve 20
    STAB $2001       ; Store B (20) in $2001
