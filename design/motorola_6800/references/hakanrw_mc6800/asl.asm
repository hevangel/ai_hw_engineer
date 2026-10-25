; MC6800 ASL (Arithmetic Shift Left) Comprehensive Test Program
; Tests all addressing modes and flag conditions

; Immediate Mode Test
IMM_TEST:
	LDX	#$2000        ; Test 1
        LDAA    #%01000000   ; Test with value that will set V flag
        ASL     A             ; Shift left - should set V flag
        BVS     V_SET_OK      ; Branch if overflow flag set
        BRA     TEST_FAIL      

V_SET_OK:
	LDX	#$2001        ; Test 2
        LDAA    #%01000000   ; Test with value that will set N flag
        ASL     A             ; Shift left - should set N flag
        BMI     N_SET_OK      ; Branch if negative flag set
        BRA     TEST_FAIL      

N_SET_OK:
	LDX	#$2002        ; Test 3
        LDAA    #%00000000   ; Test with zero value
        ASL     A             ; Shift left - should set Z flag
        BEQ     Z_SET_OK      ; Branch if zero flag set
        BRA     TEST_FAIL      

Z_SET_OK:
	LDX	#$2003        ; Test 4
        LDAA    #%10000001   ; Test with value that will set C flag
        ASL     A             ; Shift left - should set carry flag
        BCS     C_SET_OK      ; Branch if carry flag set
        BRA     TEST_FAIL      

; Direct Addressing Mode Test
C_SET_OK:
	LDX	#$2004        ; Test 5
        LDAA    #$55
        STAA    $F0            ; Store test value in direct page
        ASL     $F0            ; Direct addressing mode test
        BNE     DIR_TEST_OK    ; Ensure result is not zero
        BRA     TEST_FAIL

; Indexed Addressing Mode Test
DIR_TEST_OK:
	LDX	#$2005        ; Test 6
        LDX     #$FF           ; Index register points to test location
        LDAA    #%01010101     ; Test value
        STAA    $00,X          ; Store in indexed location
        ASL     $00,X          ; Indexed addressing mode test
        BNE     IDX_TEST_OK    ; Ensure result is not zero
        BRA     TEST_FAIL

; Extended Addressing Mode Test
IDX_TEST_OK:
	LDX	#$2006        ; Test 7
        STAA    $2000          ; Store test value in extended memory
        ASL     $2000          ; Extended addressing mode test
        BNE     EXT_TEST_OK    ; Ensure result is not zero
        BRA     TEST_FAIL

; Test Successful - Halt
EXT_TEST_OK:
	CLR	$2000
	BRA END

; Failure Handling
TEST_FAIL:
        LDAA    #$FF           ; Load failure indicator
	STAA	,X
	BRA END

END:
