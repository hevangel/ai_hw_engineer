; MC6800 ADD (Add Without Carry) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	LDX     #$2001        ; Test 1
	LDAA    #$00
	ADDA    #$01          ; N=0 Z=0 V=0 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA	#$01
	BNE     TEST_FAIL

TEST_2:
	LDX     #$2002        ; Test 2
	LDAA    #$08
	ADDA    #$08          ; N=0 Z=0 V=0 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$10
	BNE     TEST_FAIL

TEST_3:
	LDX     #$2003        ; Test 3
	LDAA    #$70
	ADDA    #$0F          ; N=0 Z=0 V=0 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$7F
	BNE     TEST_FAIL

TEST_4:
	LDX     #$2004        ; Test 4
	LDAA    #$10
	ADDA    #$70          ; N=1 Z=0 V=1 C=0

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$80
	BNE     TEST_FAIL

TEST_5:
	LDX     #$2005        ; Test 5
	LDAA    #$80
	ADDA    #$80          ; N=0 Z=1 V=1 C=1

	BMI     TEST_FAIL
	BNE     TEST_FAIL
	BVC     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #$00
	BNE     TEST_FAIL

TEST_6:
	LDX     #$2006        ; Test 6
	LDAA    #$FF
	ADDA    #$FF          ; N=1 Z=0 V=0 C=1

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC	TEST_FAIL
	CMPA    #$FE
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
