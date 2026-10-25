    ; Initialize CCR flags with a known state
    TPA             ; Get default flags
    STAA  $2000

    ; Test SEC (Set Carry) and CLC (Clear Carry)
    SEC
    TPA             ; Capture CCR
    STAA  $2001
    CLC
    TPA             ; Capture CCR
    STAA  $2002

    ; Test SEV (Set Overflow) and CLV (Clear Overflow)
    SEV
    TPA             ; Capture CCR
    STAA  $2003
    CLV
    TPA             ; Capture CCR
    STAA  $2004

    ; Test SEI (Set Interrupt) and CLI (Clear Interrupt)
    SEI
    TPA             ; Capture CCR
    STAA  $2005
    CLI
    TPA             ; Capture CCR
    STAA  $2006

    SEC
    SEV
    SEI
    TPA
    STAA  $2009
    CLC
    CLV
    CLI
    TPA
    STAA  $200A

    CLRA
    TAP             ; Clear all flags except X and Y (default state)
    TPA
    STAA  $200B
