    LDAA #2      ; Load 2 into A
    INCA         ; Increment A (A = 3)
    DECA         ; Decrement A (A = 2)
    ADDA #4      ; Add 4 to A
    STAA $2000   ; Store result (6) in $2000
