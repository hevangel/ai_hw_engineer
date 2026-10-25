      JMP  SKP1
      LDAA #20     ; Load 20 into A
SKP1: STAA $2000   ; Store A in $2000
      LDAA #15     ; Load 15 into A
      STAA $2001   ; Store A in $2001

      JMP  SKP2
      LDAA #12
SKP2: STAA $2002

      LDX  #SKP3
      JMP  2,X
      LDAA #1
SKP3: LDAA #2
      LDAB #3
      STAA $2003
      STAB $2004

      LDX  #SKP4
      JMP  0,X
SKP4: LDAA #25
      STAA $2005
