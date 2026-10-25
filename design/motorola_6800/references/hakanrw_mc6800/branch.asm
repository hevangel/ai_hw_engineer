      LDAA  #100
      BRA   BRA0
      STAA  $200A  ; must not execute
BRA0:
      LDAA  #2
      STAA  $2000
      LDAA  #3
      STAA  $2001

      CMPA  $2000  ; compare 3 and 2
      BEQ   BRA1   ; will fail, should stay here
      LDAA  #0
      STAA  $2002  ; must be 0 (not-equal)
      BRA   BAF1   ; jump over then statement
BRA1: 
      LDAA  #1
      STAA  $2002  ; 1 for equal
BAF1:

      LDAA  #4
      STAA  $2003
      LDAA  #5
      STAA  $2004

      CMPA  $2003  ; compare 4 and 5
      BNE   BRA2   ; will success, go to bra2
      LDAA  #1
      STAA  $2005  ; 1 for equal
      BRA   BAF2   ; jump over then statement
BRA2:
      LDAA  #0
      STAA  $2005  ; 0 for not equal
BAF2:

      LDAA  #6
      STAA  $2006
      LDAA  #6
      STAA  $2007

      CMPA  $2006  ; compare 6 and 6
      BNE   BRA3   ; will fail, continue
      LDAA  #1
      STAA  $2008  ; 1 for equal
      BRA   BAF3   ; jump over then statement
BRA3:
      LDAA  #0
      STAA  $2008  ; 0 for not equal
BAF3:
