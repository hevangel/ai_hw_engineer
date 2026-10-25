    LDAA #10     ; Load 10 into A
    ADDA #6      ; Add 6 to A (A = 16)
    INCA         ; Increment A (A = 17)
    SBCA #2      ; Subtract 2 with carry (A = 15)
    STAA $2000   ; Store result (15) in $2000

    LDAA #$FF
    INCA ; A 0 now, but inca does not affect carry
    ADCA #0
    STAA $2001 ; must be 0

    LDAA #$FF
    ADDA #1
    ADCA #0
    STAA $2002 ; must be 1
