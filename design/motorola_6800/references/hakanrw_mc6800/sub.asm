; MC6800 SUB (Substract Without Carry) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	LDX     #$2001        ; Test 1
	LDAA    #$01
	SUBA    #$01          ; N=0 Z=1 V=0 C=0

	BMI     TEST_FAIL
	BNE     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA	#$00
	BNE     TEST_FAIL

TEST_2:
	LDX     #$2002        ; Test 2
	LDAA    #$1E
	SUBA    #$0F          ; N=0 Z=0 V=0 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$0F
	BNE     TEST_FAIL

TEST_3:
	LDX     #$2003        ; Test 3
	LDAA    #$FF
	SUBA    #$0F          ; N=1 Z=0 V=0 C=0

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$F0
	BNE     TEST_FAIL

TEST_4:
	LDX     #$2004        ; Test 4
	LDAA    #$10
	SUBA    #$70          ; N=1 Z=0 V=0 C=1

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #$A0
	BNE     TEST_FAIL

TEST_5:
	LDX     #$2005        ; Test 5
	LDAA    #$80
	SUBA    #$01          ; N=0 Z=0 V=1 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCS     TEST_FAIL
	CMPA    #$7F
	BNE     TEST_FAIL

TEST_6:
	LDX     #$2006        ; Test 6
	LDAA    #$80
	SUBA    #$81          ; N=1 Z=0 V=0 C=1

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
