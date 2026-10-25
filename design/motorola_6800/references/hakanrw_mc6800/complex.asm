    ; Initialize values in A and B
    LDAA #50         ; Load 50 into A
    STAA $2000       ; Store A (50) in $2000

    LDAB #20         ; Load 20 into B
    STAB $2001       ; Store B (20) in $2001

    ; Perform addition and store results
    ADDA #10         ; A = A + 10 -> A = 60
    STAA $2002       ; Store A (60) in $2002

    ADDB $2000       ; B = B + M[$2000] (50) -> B = 70
    STAB $2003       ; Store B (70) in $2003

    ; Perform subtraction and store results
    LDAA #100        ; Load 100 into A
    SBCA #25         ; A = A - 25 with borrow -> A = 75
    STAA $2004       ; Store A (75) in $2004

    ; Load values, add with carry, and store
    LDAA $2003       ; Load A with M[$2003] (70)
    ADCA #5          ; A = A + 5 with carry -> A = 75
    STAA $2005       ; Store A (75) in $2005

    ; Increment and decrement operations
    LDAA #15         ; Load 15 into A
    INCA             ; Increment A -> A = 16
    DECA             ; Decrement A -> A = 15
    STAA $2006       ; Store A (15) in $2006

    LDAB #40         ; Load 40 into B
    INC $2006        ; Increment M[$2006] (15) -> M[$2006] = 16
    STAB $2007       ; Store B (40) in $2007

    ; Perform combined operations and store
    LDAA $2002       ; Load A with M[$2002] (60)
    ADDA $2001       ; A = A + M[$2001] (20) -> A = 80
    DECA             ; A = A - 1 -> A = 79
    STAA $2008       ; Store A (79) in $2008

    ; Wrap-around test (no overflow flag on 127 + 1)
    LDAA #127        ; Load A with 127
    ADDA #1          ; A = A + 1, wraps around to 128 in unsigned logic
    STAA $2009       ; Store A (128) in $2009

    ; Complex carry manipulation
    LDAA #255        ; Load A with 255 (0xFF)
    ADCA #1          ; A = A + 1 with carry, wrap to 0
    STAA $200A       ; Store A (0) in $200A

    ; Final subtraction sequence
    LDAA $2005       ; Load A with M[$2005] (75)
    SBCA $2004       ; A = A - M[$2004] (75) with carry -> A = 0
    STAA $200B       ; Store A (0) in $200B
