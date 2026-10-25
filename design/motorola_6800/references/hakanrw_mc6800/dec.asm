; MC6800 DEC (Decrement) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	SEC
	LDX     #$2001        ; Test 1
	LDAA    #$00
	DECA                  ; N=1 Z=0 V=0 C=x

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA	#$FF
	BNE     TEST_FAIL

TEST_2:
	SEC
	LDX     #$2002        ; Test 2
	LDAA    #$01
	DECA                  ; N=0 Z=1 V=0 C=x

	BMI     TEST_FAIL
	BNE     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL

	CMPA    #$00
	BNE     TEST_FAIL

TEST_3:
	SEC
	LDX     #$2003        ; Test 3
	LDAA    #$FF
	DECA                  ; N=1 Z=0 V=0 C=x

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #$FE
	BNE     TEST_FAIL

TEST_4:
	CLC
	LDX     #$2004        ; Test 4
	LDAA    #$80
	DECA                  ; N=0 Z=0 V=1 C=x

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$7F
	BNE     TEST_FAIL

TEST_5:
	CLC
	LDX     #$2005        ; Test 5
	LDAA    #$10
	DECA                  ; N=0 Z=0 V=0 C=x

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$0F
	BNE     TEST_FAIL

TEST_6:
	CLC
	LDX     #$2006        ; Test 6
	LDAA    #$81
	DECA                  ; N=1 Z=0 V=0 C=x

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS	TEST_FAIL
	CMPA    #$80
	BNE     TEST_FAIL

; Test Successful - Halt
EXT_TEST_OK:
	CLR     $2000
	BRA END

; Failure Handling
TEST_FAIL:
	LDAA	#$FF
	STAA	,X
	BRA END

END:
