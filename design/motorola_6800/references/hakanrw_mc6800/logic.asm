; Test ANDX operation
    ORG   $1000          ; Start program at address $1000
    LDAA  #$F2           ; Load accumulator A with value to AND with
    LDAB  #$F1
    STAA  $2000
    STAB  $2001          ; Store accumulator A at $1002
    ANDA  $2001          ; ANDX operation: X = X & Mem[$1002]
    STAA  $2002          ; Store the result of X register at $1004

    LDAA  #$F0
    LDAB  #$0F
    STAA  $2003
    STAB  $2004
    ORAA  $2004
    STAA  $2005

    LDAA  #$0F
    LDAB  #$0F
    STAA  $2006
    STAB  $2007
    EORA  $2007
    STAA  $2008
