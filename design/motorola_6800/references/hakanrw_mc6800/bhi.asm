      ; compare unsigned
      LDAB  #100
      STAB  $2000
      LDAA  #200
      STAA  $2001

      CMPA  $2000 ; compare 200 with 100
      BHI   TRU1
      BRA   FLS1
TRU1:
      STAA  $2002
      BRA   END1
FLS1:
      STAB  $2002
END1:

      LDAB  #200
      STAB  $2003
      LDAA  #100
      STAA  $2004

      CMPA  $2003 ; compare 100 with 200
      BHI   FLS2
TRU2:
      STAA  $2005
      BRA   END2
FLS2:
      STAB  $2005
END2:

      LDAB  #200
      STAB  $2006
      LDAA  #200
      STAA  $2007

      CMPA  $2006 ; compare 200 with 200
      BHI   FLS3
TRU3:
      STAA  $2008
      BRA   END3
FLS3:
END3:

