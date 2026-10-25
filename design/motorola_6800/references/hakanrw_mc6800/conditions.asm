      ; PL/MI
      LDAA  #-1
      BPL   FLS1
      BRA   TRU1
FLS1: 
      LDAA  #2
      STAA  $2000
      BRA   END1
TRU1:
      LDAA  #1
      STAA  $2000
END1:

      LDAA  #0
      BPL   TRU2
FLS2: 
      LDAA  #2
      STAA  $2001
      BRA   END2
TRU2:
      LDAA  #1
      STAA  $2001
END2:

      LDAA  #-1
      BMI   TRU3
FLS3: 
      LDAA  #2
      STAA  $2002
      BRA   END3
TRU3:
      LDAA  #1
      STAA  $2002
END3:

      LDAA  #0
      BMI   FLS4
      BRA   TRU4
FLS4: 
      LDAA  #2
      STAA  $2003
      BRA   END4
TRU4:
      LDAA  #1
      STAA  $2003
END4:

      ; ZERO
      LDAA  #-1
      BEQ   FLS5
      BRA   TRU5
FLS5: 
      LDAA  #2
      STAA  $2004
      BRA   END5
TRU5:
      LDAA  #1
      STAA  $2004
END5:

      LDAA  #0
      BEQ   TRU6
FLS6: 
      LDAA  #2
      STAA  $2005
      BRA   END6
TRU6:
      LDAA  #1
      STAA  $2005
END6:

      LDAA  #-1
      BNE   TRU7
FLS7: 
      LDAA  #2
      STAA  $2006
      BRA   END7
TRU7:
      LDAA  #1
      STAA  $2006
END7:

      LDAA  #0
      BNE   FLS8
      BRA   TRU8
FLS8: 
      LDAA  #2
      STAA  $2007
      BRA   END8
TRU8:
      LDAA  #1
      STAA  $2007
END8:

      ; CARRY
      LDAA  #255
      ADDA  #1
      BCC   FLS9
      BRA   TRU9
FLS9: 
      LDAA  #2
      STAA  $2008
      BRA   END9
TRU9:
      LDAA  #1
      STAA  $2008
END9:

      LDAA  #255
      ADDA  #0
      BCC   TRUA
FLSA: 
      LDAA  #2
      STAA  $2009
      BRA   ENDA
TRUA:
      LDAA  #1
      STAA  $2009
ENDA:

      LDAA  #128
      ADDA  #127
      BCS   FLSB
      BRA   TRUB
FLSB: 
      LDAA  #2
      STAA  $200A
      BRA   ENDB
TRUB:
      LDAA  #1
      STAA  $200A
ENDB:

      LDAA  #128
      ADDA  #128
      BCS   TRUC
FLSC: 
      LDAA  #2
      STAA  $200B
      BRA   ENDC
TRUC:
      LDAA  #1
      STAA  $200B
ENDC:


