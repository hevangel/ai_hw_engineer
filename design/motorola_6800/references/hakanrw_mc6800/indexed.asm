    JMP BEGIN

TABLE:
    FCB 10
    FCB 20
    FCB 30
    FCB 40
    FCB 50

BEGIN:
    LDX   #TABLE
    LDAA  0,X
    LDAB  1,X

    LDX   #$2000
    STAA  0,X
    STAB  1,X

    LDX   #TABLE
    LDAA  4,X
    LDAB  3,X

    STAA  $2002
    STAB  $2003
