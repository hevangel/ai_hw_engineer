; MC6800 COM (Complement) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	LDX     #$2001        ; Test 1
	LDAA    #%00000000
	COMA                  ; N=1 Z=0 V=0 C=1

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA	#%11111111
	BNE     TEST_FAIL

TEST_2:
	LDX     #$2002        ; Test 2
	LDAA    #%00000001
	COMA                  ; N=1 Z=0 V=0 C=1

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #%11111110
	BNE     TEST_FAIL

TEST_3:
	LDX     #$2003        ; Test 3
	LDAA    #%01000000
	COMA                  ; N=1 Z=0 V=0 C=1

	BPL     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #%10111111
	BNE     TEST_FAIL

TEST_4:
	LDX     #$2004        ; Test 4
	LDAA    #%10000000
	COMA                  ; N=0 Z=0 V=0 C=1

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #%01111111
	BNE     TEST_FAIL

TEST_5:
	LDX     #$2005        ; Test 5
	LDAA    #%11000000
	COMA                  ; N=0 Z=0 V=0 C=1

	BMI     TEST_FAIL
	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCC     TEST_FAIL
	CMPA    #%00111111
	BNE     TEST_FAIL

TEST_6:
	LDX     #$2006        ; Test 6
	LDAA    #%11111111
	COMA                  ; N=0 Z=1 V=0 C=1

	BMI     TEST_FAIL
	BNE     TEST_FAIL
	BVS     TEST_FAIL
	BCC	TEST_FAIL
	CMPA    #%00000000
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
