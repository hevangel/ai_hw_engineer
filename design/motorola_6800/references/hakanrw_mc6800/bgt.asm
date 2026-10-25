; Test 1: Compare -50 (A) with 20 (B)
      LDAB  #20         ; Load +20 into B
      STAB  $2000       ; Store B at $2000
      LDAA  #-50        ; Load -50 into A
      STAA  $2001       ; Store A at $2001

      CMPA  $2000       ; Compare A (-50) with $2000 (20)
      BGT   TRU1        ; Branch to TRU1 if A > B (signed)
      BRA   FLS1        ; Otherwise, branch to FLS1
TRU1:
      STAA  $2002       ; Store A in $2002 if A > B
      BRA   END1        ; End of Test 1
FLS1:
      STAB  $2002       ; Store B in $2002 if A <= B
END1:

; Test 2: Compare 30 (A) with -40 (B)
      LDAB  #-40        ; Load -40 into B
      STAB  $2003       ; Store B at $2003
      LDAA  #30         ; Load +30 into A
      STAA  $2004       ; Store A at $2004

      CMPA  $2003       ; Compare A (30) with $2003 (-40)
      BGT   TRU2        ; Branch to TRU2 if A > B (signed)
      BRA   FLS2        ; Otherwise, branch to FLS2
TRU2:
      STAA  $2005       ; Store A in $2005 if A > B
      BRA   END2        ; End of Test 2
FLS2:
      STAB  $2005       ; Store B in $2005 if A <= B
END2:

; Test 3: Compare -128 (A) with -128 (B)
      LDAB  #-128       ; Load -128 into B
      STAB  $2006       ; Store B at $2006
      LDAA  #-128       ; Load -128 into A
      STAA  $2007       ; Store A at $2007

      CMPA  $2006       ; Compare A (-128) with $2006 (-128)
      BGT   FLS3        ; Branch to FLS3 if A > B (signed)
      BRA   TRU3
FLS3:
      LDAB  #2
      STAB  $2008       ; Store B in $2008 if A <= B
      BRA   END3        ; End of Test 3
TRU3:
      LDAA  #1
      STAA  $2008       ; Store A in $2008 if A > B
END3:

; Fill unused memory
      CLR   $2009
      CLR   $200A
      CLR   $200B
