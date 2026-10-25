    LDAA #20     ; Load 20 into A
    STAA $2000   ; Store A in $2000
    LDAA #15     ; Load 15 into A
    STAA $2001   ; Store A in $2001

    LDX  #$0101
    STX  $2002

    LDS  #$00F0
    STS  $2004

    LDX  #$FF00
    STX  $2006
