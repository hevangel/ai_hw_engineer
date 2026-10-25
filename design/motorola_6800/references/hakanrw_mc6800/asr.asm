; MC6800 ASR (Arithmetic Shift Right) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	LDX     #$2001        ; Test 1
	LDAA    #%00000000
	ASRA                  ; N=0 Z=1 V=0 C=0

	BMI     TEST_FAIL
	BNE     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	BRA     TEST_2        ; All good

TEST_2:
	LDX     #$2002        ; Test 2
	LDAA    #%00000001
	ASRA                  ; N=0 Z=1 V=1 C=1

	BMI     TEST_FAIL
	BNE     TEST_FAIL
	BVC     TEST_FAIL
	BCC     TEST_FAIL
	BRA     TEST_3        ; All good

TEST_3:
	LDX     #$2003        ; Test 3
	LDAA    #%01000000
	ASRA                  ; N=0 Z=0 V=0 C=0

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	BRA     TEST_4        ; All good

TEST_4:
	LDX     #$2004        ; Test 4
	LDAA    #%10000000
	ASRA                  ; N=1 Z=0 V=1 C=0

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCS     TEST_FAIL
	BRA     TEST_5        ; All good

TEST_5:
	LDX     #$2005        ; Test 5
	LDAA    #%11000000
	ASRA                  ; N=1 Z=0 V=1 C=0

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCS     TEST_FAIL
	BRA     TEST_6        ; All good

TEST_6:
	LDX     #$2006        ; Test 6
	LDAA    #%11111111
	ASRA                  ; N=1 Z=0 V=0 C=1

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC	TEST_FAIL
	CMPA    #%11111111
	BEQ     EXT_TEST_OK   ; All good
	BRA     TEST_FAIL

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
