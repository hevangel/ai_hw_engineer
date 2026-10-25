; Test from https://github.com/nirkog/Momulator
; MIT License - Copyright (c) 2021 nirkog

; The entry point of the program
l_start
	jmp l_test_aba_adc

; Test the ABA and ADC instructions
l_test_aba_adc
	adcb #$f0
	adcb #$10
	adcb #$00
	cmpb #$01
	bne l_aba_adc_error
	aba
	cmpb #$01
	bne l_aba_adc_error
	bra l_aba_adc_end
l_aba_adc_error
	jmp l_error
l_aba_adc_end
	jmp l_test_add

; Test the ADD instruction
l_test_add
	ldaa #0
	adda #$f2
	cmpa #$f2
	bne l_add_error
	adda #$10
	cmpa #$02
	bne l_add_error
	ldab #0
	addb #$f2
	cmpb #$f2
	bne l_add_error
	addb #$10
	cmpb #$02
	bne l_add_error
	bra l_add_end
l_add_error
	jmp l_error
l_add_end
	jmp l_test_and

; Test the AND instruction 
l_test_and
	ldaa #$c5
	anda #$27
	cmpa #$05
	bne l_and_error
	ldab #$1b
	andb #$82
	cmpb #$2
	bne l_and_error
	bra l_and_end
l_and_error
	jmp l_error
l_and_end
	jmp l_test_asr_asl


; Test the ASL and ASR instructions
l_test_asr_asl
	ldaa #$c3
	asla
	bcc l_asr_asl_error
	cmpa #$86
	bne l_asr_asl_error
	ldaa #$a6
	asra
	bcs l_asr_asl_error
	cmpa #$d3
	bne l_asr_asl_error

	ldab #$73
	aslb
	bcs l_asr_asl_error
	cmpb #$e6
	bne l_asr_asl_error
	ldab #$f7
	asrb
	bcc l_asr_asl_error
	cmpb #$fb
	bne l_asr_asl_error
	bra l_asr_asl_end
l_asr_asl_error
	jmp l_error
l_asr_asl_end
	jmp l_test_bcc_sec

; Test the BCC, BCS and SEC, CLC instructions
l_test_bcc_sec
	sec
	bcc l_bcc_sec_error
	clc
	bcs l_bcc_sec_error
	bra l_bcc_sec_end
l_bcc_sec_error
	jmp l_error
l_bcc_sec_end
	jmp l_test_branch

; Test most of the conditionall branching instructions and the unconditionall branch
l_test_branch
	ldaa #$05
	cmpa #$12
	beq l_branch_error
	bge l_branch_error
	cmpa #$05
	beq l_after_beq
l_after_beq
	cmpa #$02
	bge l_after_bge
l_after_bge
	cmpa #$05
	bgt l_branch_error
	cmpa #$2c
	bgt l_branch_error
	cmpa #$03
	bgt l_after_bgt
l_after_bgt	
	cmpa #$ff
	bhi l_branch_error
	cmpa #$02
	bhi l_after_bhi
l_after_bhi
	cmpa #$c2
	ble l_branch_error
	cmpa #$32
	ble l_after_ble
l_after_ble
	cmpa #$03
	bls l_branch_error
	cmpa #$d9
	bls l_after_bls
l_after_bls	
	cmpa #$a9
	blt l_branch_error
	cmpa #$25
	blt l_after_blt
l_after_blt
	cmpa #$01
	bmi l_branch_error
	cmpa #$07
	bmi l_after_bmi
l_after_bmi
	cmpa #$05
	bne l_branch_error
	cmpa #$b8
	bne l_after_bne
l_after_bne
	cmpa #$20
	bpl l_branch_error
	cmpa #$04
	bpl l_branch_always
l_branch_always
	bra l_branch_end
l_branch_error
	jmp l_error
l_branch_end
	jmp l_test_bit

; Test the BIT instruction
l_test_bit
	bra l_bit_end
l_bit_error
	jmp l_error
l_bit_end
	jmp l_test_bsr_rts

; A test function that does nothing
l_test_func
	ldaa #$13
	ldab #$37
	rts

; Test subroutine related instruction (BSR, RTS)
l_test_bsr_rts
	lds #$1000
	bsr l_test_func
	jmp l_test_bvc_bvs

; Test the BVC and BVS instructions
l_test_bvc_bvs
	sev
	bvc l_bvc_bvs_error
	clv
	bvc l_after_bvc
l_after_bvc
	clv
	bvs l_bvc_bvs_error
	sev
	bvs l_bvc_bvs_end
l_bvc_bvs_error
	jmp l_error
l_bvc_bvs_end
	jmp l_test_cba

; Test the CBA instruction
l_test_cba
	ldaa #$02
	ldab #$05
	cba
	bgt l_cba_error
	bge l_cba_error
	ldaa #$32
	ldab #$23
	cba
	ble l_cba_error
	jmp l_test_clr
l_cba_error
	jmp l_error

; Test the CLR instruction
l_test_clr
	ldaa #$12
	clra
	cmpa #$00
	bne l_clr_error
	staa $2000
	clr  $2000
	ldaa $2000
	cmpa #$00
	bne l_clr_error
	jmp l_test_com
l_clr_error
	jmp l_error

; Test the COM instruction
l_test_com
	ldaa #$e7
	coma
	cmpa #$18
	bne l_com_error
	ldaa #$3c
	staa $2000
	com $2000
	ldaa $2000
	cmpa #$c3
	bne l_com_error
	ldaa #$12
	ldx #$2000
	staa $00, x
	com $00, x
	ldaa $00, x
	cmpa #$ed
	bne l_com_error
	jmp l_test_cpx
l_com_error
	jmp l_error

; Test the CPX instruction
l_test_cpx
	ldx #$3412
	ldaa #$34
	ldab #$12
	staa $2000
	stab $2001
	cpx $2000
	bne l_cpx_error
	cpx #$4412
	bge l_cpx_error
	jmp l_test_dec_inc
l_cpx_error
	jmp l_error

; Test the DEC and INC instructions
l_test_dec_inc
	ldaa #$34
	deca
	cmpa #$33
	bne l_dec_inc_error
	inca
	cmpa #$34
	bne l_dec_inc_error
	ldaa #$0
	deca
	cmpa #$ff
	bne l_dec_inc_error
	inca
	cmpa #$00
	bne l_dec_inc_error
	ldaa #$54
	staa $2000
	dec $2000
	ldaa $2000
	cmpa #$53
	bne l_dec_inc_error
	jmp l_test_des_dex
l_dec_inc_error
	jmp l_error

; Test the DES and DEX instructions
l_test_des_dex
	lds #$1337
	des
	sts $2000
	ldaa $2000
	ldab $2001
	cmpa #$13
	bne l_des_dex_error
	cmpb #$36
	bne l_des_dex_error
	ldx #$dead
	dex
	stx $2000
	ldaa $2000
	ldab $2001
	cmpa #$de
	bne l_des_dex_error
	cmpb #$ac
	bne l_des_dex_error
	jmp l_test_eor
l_des_dex_error
	jmp l_error

; Test the EOR instruction
l_test_eor
	ldaa #$33
	eora #$86
	cmpa #$b5
	bne l_eor_error
	jmp l_test_ins_inx
l_eor_error
	jmp l_error

; Test the INS and INX instructions
l_test_ins_inx
	lds #$1337
	ins
	sts $2000
	ldaa $2000
	ldab $2001
	cmpa #$13
	bne l_ins_inx_error
	cmpb #$38
	bne l_ins_inx_error
	ldx #$dead
	inx
	stx $2000
	ldaa $2000
	ldab $2001
	cmpa #$de
	bne l_ins_inx_error
	cmpb #$ae
	bne l_ins_inx_error
	jmp l_test_jsr
l_ins_inx_error
	jmp l_error

; Test the jst instruction
l_test_jsr
; The test is commented out because of a bug in the assembler
; 	jsr l_test_func
	jmp l_test_lsr

; Test the LSR instruction
l_test_lsr
	ldaa #$17
	lsra
	bcc l_lsr_error
	cmpa #$0b
	bne l_lsr_error
	jmp l_test_neg
l_lsr_error
	jmp l_error

; Test the NEG instruction
l_test_neg
	ldaa #$f3
	nega
	cmpa #$0d
	bne l_neg_error
	jmp l_test_nop
l_neg_error
	jmp l_error

; Test the NOP instruction
l_test_nop
	nop
	jmp l_test_ora

; Test the ORA instruction
l_test_ora
	ldaa #$5c	
	oraa #$d7
	cmpa #$df
	bne l_ora_error
	jmp l_test_pul_psh
l_ora_error
	jmp l_error

; Test the PSH and PUL instructions
l_test_pul_psh
	lds #$2000
	ldaa #$13
	ldab #$37
	psha
	pshb
	pula
	pulb
	cmpa #$37
	bne l_pul_psh_error
	cmpb #$13
	bne l_pul_psh_error
	jmp l_test_rol_ror
l_pul_psh_error
	jmp l_error

; Test the ROL and ROR instructions
l_test_rol_ror
	clc
	ldaa #$64
	rora
	bcs l_rol_ror_error	
	cmpa #$32
	bne l_rol_ror_error
	sec
	ldaa #$13
	rora
	bcc l_rol_ror_error
	cmpa #$89	
	bne l_rol_ror_error
	clc
	ldaa #$64
	rola
	bcs l_rol_ror_error	
	cmpa #$c8
	bne l_rol_ror_error
	sec
	ldaa #$93
	rola
	bcc l_rol_ror_error
	cmpa #$27	
	bne l_rol_ror_error
	jmp l_test_sba
l_rol_ror_error
	jmp l_error

; Test the SBA instruction
l_test_sba
	ldaa #$f2
	ldab #$54
	sba
	cmpa #$9e
	bne l_sba_error
	ldab #$a2
	sba
	cmpa #$fc
	bne l_sba_error
	jmp l_test_sbc
l_sba_error
	jmp l_error

; Test the SBC instruction
l_test_sbc
	ldaa #$a2
	clc
	sbca #$12
	cmpa #$90
	bne l_sbc_error
	sec
	sbca #$15
	cmpa #$7a
	bne l_sbc_error
	jmp l_test_sub
l_sbc_error
	jmp l_error

; Test the SUB instruction
l_test_sub
	ldaa #$43
	suba #$f5
	cmpa #$4e
	bne l_test_error
	ldaa #$12
	suba #$3
	cmpa #$0f
	bne l_test_error
	jmp l_test_tab_tba
l_test_error
	jmp l_error

; Test the TAB and TBA instructions
l_test_tab_tba
	ldaa #$82
	tab
	cmpb #$82
	bne l_tab_tba_error
	ldab #$cd
	tba
	cmpb #$cd
	bne l_tab_tba_error
	jmp l_test_tap_tpa
l_tab_tba_error
	jmp l_error

; Test the TAP and TPA instructions
l_test_tap_tpa
	ldaa #$3
	suba #$4
	clc
	sev
	sei
	tpa
	cmpa #$da
	bne l_tap_tpa_error
	ldaa #$3
	tap
	bvc l_tap_tpa_error
	bcc l_tap_tpa_error
	jmp l_test_tst
l_tap_tpa_error
	jmp l_error

; Test the TST instruction
l_test_tst
	ldaa #$f8
	tsta
	beq l_tst_error
	ldaa #$00
	bne l_tst_error
	jmp l_test_tsx_txs
l_tst_error
	jmp l_error

; Test the TSX and TXS instructions
l_test_tsx_txs
	lds #$8202
	tsx
	cpx #$8203
	bne l_tsx_txs_error
	ldx #$1338
	txs
	ldaa #$13
	ldab #$37
	psha
	pshb
	ldab $1337
	ldaa $1336
	cmpa #$37
	bne l_tsx_txs_error
	cmpb #$13
	bne l_tsx_txs_error
	jmp l_success
l_tsx_txs_error
	jmp l_error

; Something went wrong
l_error
	ldaa #1
	staa $2001
	bra end

; Everything was OK!
l_success
	clr  $2001
	ldaa #100
	staa $2000

end:
