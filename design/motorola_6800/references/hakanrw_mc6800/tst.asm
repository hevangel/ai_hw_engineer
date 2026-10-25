START:
    ; Test TSTA
    LDAA #$00       ; Load A with 0
    TSTA            ; Test A
    TPA             ; Transfer CCR to A
    STAA $2000      ; Store CCR into $2000

    LDAA #$80       ; Load A with a negative value
    TSTA            ; Test A
    TPA             ; Transfer CCR to A
    STAA $2001      ; Store CCR into $2001

    ; Test TSTB
    LDAB #$00       ; Load B with 0
    TSTB            ; Test B
    TPA             ; Transfer CCR to A
    STAA $2002      ; Store CCR into $2002

    LDAB #$7F       ; Load B with a positive value
    TSTB            ; Test B
    TPA             ; Transfer CCR to A
    STAA $2003      ; Store CCR into $2003

    ; Test TSX
    LDX #$1234      ; Load X with $1234
    TXS             ; Transfer X to SP
    TSX             ; Test SP
    TPA             ; Transfer CCR to A
    STAA $2004      ; Store CCR into $2004

    LDX #$0000      ; Load X with 0
    TPA             ; Transfer CCR to A
    STAA $2005      ; Store CCR into $2005

    LDX #$F000      ; Load X with 0
    TPA             ; Transfer CCR to A
    STAA $2006      ; Store CCR into $2005

    ; Check accumulator contents
    LDAA #$01       ; Load A with a positive value
    TSTA            ; Test A
    TPA             ; Transfer CCR to A
    STAA $2008      ; Store CCR into $2008

    LDAB #$FF       ; Load B with a negative value
    TSTB            ; Test B
    TPA             ; Transfer CCR to A
    STAA $2009      ; Store CCR into $2009

    ; Ensure the X register flags behave correctly
    LDX #$FFFF      ; Load X with a negative value
    TSX             ; Test SP
    TPA             ; Transfer CCR to A
    STAA $200A      ; Store CCR into $200A

    LDX #$0001      ; Load X with a positive value
    TSX             ; Test SP
    TPA             ; Transfer CCR to A
    STAA $200B      ; Store CCR into $200B

    NOP             ; End of program
