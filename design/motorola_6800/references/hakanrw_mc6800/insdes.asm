    LDS #$1FF8       ; Load S with $1FF8

    INS              ; Increment SP -> SP = $1FF9
    TSX              ; Transfer SP to X
    STX $2000        ; Store X (should be $1FF9) into $2000 and $2001

    DES              ; Decrement SP -> SP = $1FF8
    TSX              ; Transfer SP to X
    STX $2002        ; Store X (should be $1FF8) into $2002 and $2003
