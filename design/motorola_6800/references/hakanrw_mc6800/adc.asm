; MC6800 ADC (Add With Carry) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	CLC
	LDX     #$2001        ; Test 1
	LDAA    #$00
	ADCA    #$01          ; N=0 Z=0 V=0 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA	#$01
	BNE     TEST_FAIL

TEST_2:
	SEC
	LDX     #$2002        ; Test 2
	LDAA    #$08
	ADCA    #$08          ; N=0 Z=0 V=0 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$11
	BNE     TEST_FAIL

TEST_3:
	SEC
	LDX     #$2003        ; Test 3
	LDAA    #$70
	ADCA    #$0F          ; N=1 Z=0 V=1 C=0

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$80
	BNE     TEST_FAIL

TEST_4:
	CLC
	LDX     #$2004        ; Test 4
	LDAA    #$10
	ADCA    #$70          ; N=1 Z=0 V=1 C=0

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$80
	BNE     TEST_FAIL

TEST_5:
	SEC
	LDX     #$2005        ; Test 5
	LDAA    #$80
	ADCA    #$80          ; N=0 Z=0 V=1 C=1

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #$01
	BNE     TEST_FAIL

TEST_6:
	SEC
	LDX     #$2006        ; Test 6
	LDAA    #$FF
	ADCA    #$FF          ; N=1 Z=0 V=0 C=1

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC	TEST_FAIL
	CMPA    #$FF
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
