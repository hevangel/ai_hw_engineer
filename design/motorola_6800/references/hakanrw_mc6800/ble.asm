; Test 1: Compare 200 (A) with 100 (B)
      LDAB  #100       ; Load 100 into B
      STAB  $2000      ; Store B at $2000
      LDAA  #200       ; Load 200 into A
      STAA  $2001      ; Store A at $2001

      CMPA  $2000      ; Compare A (200) with $2000 (100)
      BLS   FLS1       ; Branch to FLS1 if A <= B
TRU1:
      STAA  $2002      ; Store A in $2002 if A > B
      BRA   END1       ; End of Test 1
FLS1:
      STAB  $2002      ; Store B in $2002 if A <= B
END1:

; Test 2: Compare 100 (A) with 200 (B)
      LDAB  #200       ; Load 200 into B
      STAB  $2003      ; Store B at $2003
      LDAA  #100       ; Load 100 into A
      STAA  $2004      ; Store A at $2004

      CMPA  $2003      ; Compare A (100) with $2003 (200)
      BLS   TRU2       ; Branch to TRU2 if A <= B
      BRA   FLS2       ; Otherwise, branch to FLS2
TRU2:
      STAA  $2005      ; Store A in $2005 if A <= B
      BRA   END2       ; End of Test 2
FLS2:
      STAB  $2005      ; Store B in $2005 if A > B
END2:

; Test 3: Compare 200 (A) with 200 (B)
      LDAB  #200       ; Load 200 into B
      STAB  $2006      ; Store B at $2006
      LDAA  #200       ; Load 200 into A
      STAA  $2007      ; Store A at $2007

      CMPA  $2006      ; Compare A (200) with $2006 (200)
      BLS   TRU3       ; Branch to TRU3 if A <= B
      BRA   FLS3       ; Otherwise, branch to FLS3
TRU3:
      STAA  $2008      ; Store A in $2008 if A <= B
      BRA   END3       ; End of Test 3
FLS3:
END3:

; Fill unused memory
      CLR   $2009
      CLR   $200A
      CLR   $200B
