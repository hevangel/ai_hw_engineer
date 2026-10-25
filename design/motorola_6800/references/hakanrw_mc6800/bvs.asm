      ; addition
      LDAA  #127
      ADDA  #1
      BVS   TRU1
FLS1: 
      LDAA  #2
      STAA  $2000
      BRA   END1
TRU1:
      LDAA  #1
      STAA  $2000
END1:

      LDAA  #127
      ADDA  #0
      BVS   FLS2
      BRA   TRU2
FLS2: 
      LDAA  #2
      STAA  $2001
      BRA   END2
TRU2:
      LDAA  #1
      STAA  $2001
END2:

      LDAA  #128
      ADDA  #0
      BVS   FLS3
      BRA   TRU3
FLS3: 
      LDAA  #2
      STAA  $2002
      BRA   END3
TRU3:
      LDAA  #1
      STAA  $2002
END3:

      LDAA  #255
      ADDA  #1
      BVS   FLS4
      BRA   TRU4
FLS4: 
      LDAA  #2
      STAA  $2003
      BRA   END4
TRU4:
      LDAA  #1
      STAA  $2003
END4:

      LDAA  #0
      ADDA  #1
      BVS   FLS5
      BRA   TRU5
FLS5: 
      LDAA  #2
      STAA  $2004
      BRA   END5
TRU5:
      LDAA  #1
      STAA  $2004
END5:

      ; substraction
      LDAA  #128
      SUBA  #1
      BVS   TRU6
FLS6: 
      LDAA  #2
      STAA  $2005
      BRA   END6
TRU6:
      LDAA  #1
      STAA  $2005
END6:

      LDAA  #128
      SUBA  #0
      BVS   FLS7
      BRA   TRU7
FLS7: 
      LDAA  #2
      STAA  $2006
      BRA   END7
TRU7:
      LDAA  #1
      STAA  $2006
END7:

