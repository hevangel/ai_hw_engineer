; MC6800 CMP (Compare Register) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	LDX     #$2001        ; Test 1
	LDAA    #$00
	STAA	$3000
	LDAA	#$00          ; Test with 00 and 00
	CMPA	$3000         ; N=0 Z=1 V=0 C=0

        BMI     _TEST_FAIL
        BNE     _TEST_FAIL
	BVS     _TEST_FAIL
	BCS     _TEST_FAIL
        BRA     TEST_2        ; All good

_TEST_FAIL
	JMP	TEST_FAIL

TEST_2:
	LDX     #$2002        ; Test 2
	LDAA    #$FF
	STAA    $3000
	LDAA    #$FF          ; Test with FF and FF
	CMPA    $3000         ; N=0 Z=1 V=0 C=0

	BMI     TEST_FAIL
	BNE     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
        BRA     TEST_3        ; All good

TEST_3:
	LDX     #$2003        ; Test 3
        LDAA    #$00
        STAA    $3000
        LDAA    #$01          ; Test with 01 and 00
        CMPA    $3000         ; N=0 Z=0 V=0 C=0

        BMI     TEST_FAIL
        BEQ     TEST_FAIL
        BVS     TEST_FAIL
	BCS     TEST_FAIL
        BRA     TEST_4        ; All good

TEST_4:
	LDX     #$2004        ; Test 4
        LDAA    #$01
        STAA    $3000
        LDAA    #$00          ; Test with 00 and 01
        CMPA    $3000         ; N=1 Z=0 V=0 C=1

        BPL     TEST_FAIL
        BEQ     TEST_FAIL
        BVS     TEST_FAIL
        BCC     TEST_FAIL
        BRA     TEST_5        ; All good

TEST_5:
	LDX     #$2005        ; Test 5
        LDAA    #$01
        STAA    $3000
        LDAA    #$80          ; Test with 80 and 01
        CMPA    $3000         ; N=0 Z=0 V=1 C=0

        BMI     TEST_FAIL
        BEQ     TEST_FAIL
        BVC     TEST_FAIL
	BCS     TEST_FAIL
        BRA     TEST_6        ; All good

TEST_6:
	LDX     #$2006        ; Test 6
        LDAA    #$80
        STAA    $3000
        LDAA    #$01          ; Test with 01 and 80
        CMPA    $3000         ; N=1 Z=0 V=1 C=1

        BPL     TEST_FAIL
        BEQ     TEST_FAIL
        BVC     TEST_FAIL
	BCC	TEST_FAIL
        BRA     EXT_TEST_OK   ; All good


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
