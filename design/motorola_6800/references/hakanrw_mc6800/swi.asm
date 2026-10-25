START:
    LDS  #$0FFF

    LDAA #1
    STAA $2000
    SWI
    STAA $2003

    JMP EOF

SWIH:
    STAA $2001
    LDAA #2
    STAA $2002
    RTI

NMIH:

; -6 SWI
    FDB SWIH
; -4 NMI
    FDB NMIH
; -2 RESET
    FDB START

; emulator tester stops execution on file EOF
EOF:
