; Test 1: Compare -56 (A) with 42 (B)
      LDAB  #42         ; Load +42 into B
      STAB  $2000       ; Store B at $2000
      LDAA  #-56        ; Load -56 into A
      STAA  $2001       ; Store A at $2001

      CMPA  $2000       ; Compare A (-56) with $2000 (42)
      BLT   TRU1        ; Branch to TRU1 if A < B (signed)
      BRA   FLS1        ; Otherwise, branch to FLS1
TRU1:
      STAA  $2002       ; Store A in $2002 if A < B
      BRA   END1        ; End of Test 1
FLS1:
      STAB  $2002       ; Store B in $2002 if A >= B
END1:

; Test 2: Compare 42 (A) with -56 (B)
      LDAB  #-56        ; Load -56 into B
      STAB  $2003       ; Store B at $2003
      LDAA  #42         ; Load +42 into A
      STAA  $2004       ; Store A at $2004

      CMPA  $2003       ; Compare A (42) with $2003 (-56)
      BLT   FLS2        ; Branch to FLS2 if A < B (signed)
      BRA   TRU2        ; Otherwise, branch to TRU2
TRU2:
      STAA  $2005       ; Store A in $2005 if A >= B
      BRA   END2        ; End of Test 2
FLS2:
      STAB  $2005       ; Store B in $2005 if A < B
END2:

; Test 3: Compare -128 (A) with -128 (B)
      LDAB  #-128       ; Load -128 into B
      STAB  $2006       ; Store B at $2006
      LDAA  #-128       ; Load -128 into A
      STAA  $2007       ; Store A at $2007

      CMPA  $2006       ; Compare A (-128) with $2006 (-128)
      BLT   FLS3        ; Branch to FLS3 if A < B (signed)
TRU3:
      LDAA  #1
      STAA  $2008       ; Store A in $2008 if A >= B
      BRA   END3        ; End of Test 3
FLS3:
      LDAB  #2
      STAB  $2008       ; Store B in $2008 if A < B
END3:

; Fill unused memory
      CLR   $2009
      CLR   $200A
      CLR   $200B
