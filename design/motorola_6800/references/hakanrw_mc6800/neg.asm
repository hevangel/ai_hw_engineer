    LDAA  #0
    STAA  $2000
    NEGA
    STAA  $2001

    LDAA  #255
    STAA  $2002
    NEGA
    STAA  $2003

    LDAA  #$80
    STAA  $2004
    NEGA
    BVS   T0
    BRA   F0
T0:
    LDAA  #1
    STAA  $2005
    BRA   E0
F0:
    LDAA  #2
    STAA  $2005
E0:

    LDAA  #$7F
    STAA  $2006
    NEGA
    BVS   F1
T1:
    LDAA  #1
    STAA  $2007
    BRA   E1
F1:
    LDAA  #2
    STAA  $2007
E1:

    LDAA  #$80
    STAA  $2008
    NEGA
    BCS   T2
    BRA   F2
T2:
    LDAA  #1
    STAA  $2009
    BRA   E2
F2:
    LDAA  #2
    STAA  $2009
E2:

    LDAA  #0
    STAA  $200A
    NEGA
    BCS   F3
T3:
    LDAA  #1
    STAA  $200B
    BRA   E3
F3:
    LDAA  #2
    STAA  $200B
E3:
