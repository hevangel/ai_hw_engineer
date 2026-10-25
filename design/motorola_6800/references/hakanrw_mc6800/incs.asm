    LDAA #1      ; Load 1 into A
    INCA         ; Increment A (A = 2)
    INCA         ; Increment A (A = 3)
    STAA $2000   ; Store result (3) in $2000
