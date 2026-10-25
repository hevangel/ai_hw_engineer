; MC6800 CPX (Compare Index Register) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	LDAA    #1            ; Test 1
	LDX     #$0000
	STX     $3000
        LDX     #$0000        ; Test with 0000 and 0000
	SEC                   ; Set carry for x test
	CPX     $3000         ; N=0 Z=1 V=0 C=x

        BMI     TEST_FAIL
        BNE     TEST_FAIL
	BVS     TEST_FAIL
	BCC	TEST_FAIL
        BRA     TEST_2        ; All good

TEST_2:
	LDAA    #2            ; Test 2
	LDX     #$FFFF
	STX     $3000
	LDX     #$FFFF        ; Test with FFFF and FFFF
	CLC                   ; Clear carry for x test
	CPX     $3000         ; N=0 Z=1 V=0 C=x

        BMI     TEST_FAIL
        BNE     TEST_FAIL
        BVS     TEST_FAIL
	BCS	TEST_FAIL
        BRA     TEST_3        ; All good

TEST_3:
	LDAA    #3            ; Test 3
        LDX     #$0000
        STX     $3000
        LDX     #$0001        ; Test with 0001 and 0000
        CPX     $3000         ; N=0 Z=0 V=0 C=x

        BMI     TEST_FAIL
        BEQ     TEST_FAIL
        BVS     TEST_FAIL
        BRA     TEST_4        ; All good

TEST_4:
	LDAA    #4            ; Test 4
        LDX     #$0001
        STX     $3000
        LDX     #$0000        ; Test with 0000 and 0001
        CPX     $3000         ; N=1 Z=0 V=0 C=x

        BPL     TEST_FAIL
        BEQ     TEST_FAIL
        BVS     TEST_FAIL
        BRA     TEST_5        ; All good

TEST_5:
	LDAA    #5            ; Test 5
        LDX     #$0001
        STX     $3000
        LDX     #$8000        ; Test with 8000 and 0001
        CPX     $3000         ; N=0 Z=0 V=1 C=x

        BMI     TEST_FAIL
        BEQ     TEST_FAIL
        BVC     TEST_FAIL
        BRA     TEST_6        ; All good

TEST_6:
	LDAA    #6            ; Test 6
        LDX     #$8000
        STX     $3000
        LDX     #$0001        ; Test with 0001 and 8000
        CPX     $3000         ; N=1 Z=0 V=1 C=x

        BPL     TEST_FAIL
        BEQ     TEST_FAIL
        BVC     TEST_FAIL
        BRA     EXT_TEST_OK   ; All good


; Test Successful - Halt
EXT_TEST_OK:
	CLR     $2000
	BRA END

; Failure Handling
TEST_FAIL:
	STAA	$2000
	BRA END

END:
