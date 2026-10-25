; MC6800 INX (Increment Index Register) Comprehensive Test Program
; Tests all flag conditions

TEST_1:
	LDAA    #1            ; Test 1
	LDX     #$0000
	SEV                   ; Set v     for x test
	SEC                   ; Set carry for x test
	INX                   ; N=x Z=0 V=x C=x

	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCC     TEST_FAIL
	CPX     #$0001
	BNE     TEST_FAIL

TEST_2:
	LDAA    #2            ; Test 2
	LDX     #$00FF
	SEV                   ; Set v     for x test
	SEC                   ; Set carry for x test
	INX                   ; N=x Z=0 V=x C=x

	BEQ     TEST_FAIL
	BVC     TEST_FAIL
	BCC     TEST_FAIL
	CPX     #$0100
	BNE     TEST_FAIL

TEST_3:
	LDAA    #3            ; Test 3
	LDX     #$FF00
	CLV                   ; Clear v     for x test
	CLC                   ; Clear carry for x test
	INX                   ; N=x Z=0 V=x C=x

	BEQ     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CPX     #$FF01
	BNE     TEST_FAIL

TEST_4:
	LDAA    #4            ; Test 4
	LDX     #$FFFF
	CLV                   ; Clear v     for x test
	CLC                   ; Clear carry for x test
	INX                   ; N=x Z=1 V=x C=x

	BNE     TEST_FAIL
	BVS     TEST_FAIL
	BCS     TEST_FAIL
	CPX     #$0000
	BNE     TEST_FAIL


; Test Successful - Halt
EXT_TEST_OK:
	CLR     $2000
	BRA END

; Failure Handling
TEST_FAIL:
	STAA	$2000
	BRA END

END:
